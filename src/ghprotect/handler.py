from __future__ import annotations
from typing import Any, Dict, List, Tuple
import json
import os

from opawasm.main import evaluate_policy, PolicyError

# Minimal normalization utilities for GitHub events to the policy input expected by Rego
# This keeps Azure Function adapter thin while enabling local CLI reuse.


def _extract_ticket_refs(title: str, body: str, pattern: str) -> List[str]:
    import re
    combined = f"{title}\n{body}"
    try:
        rx = re.compile(pattern)
    except re.error:
        # Fallback: accept anything if pattern is invalid
        rx = re.compile(r"^.*$")
    # Return all matches that look like IDs
    matches = rx.findall(combined)
    if isinstance(matches, list):
        # Ensure list of strings
        return [m if isinstance(m, str) else m[0] for m in matches]
    return []


def _collect_pr_approvers(pr: Dict[str, Any]) -> List[str]:
    # Expect pre-enriched reviews in the payload, otherwise leave empty.
    # In production, you can call the GitHub API to list reviews and filter 'APPROVED'.
    approvals: List[str] = []
    for r in pr.get("reviews", []) or []:
        if r.get("state") == "APPROVED" and r.get("user", {}).get("login"):
            approvals.append(r["user"]["login"])
    return approvals


def build_policy_input(
    event_name: str,
    payload: Dict[str, Any],
    repo_policy: Dict[str, Any],
    repo_environments: List[str] | None = None,
) -> Dict[str, Any]:
    """
    Build the input document consumed by the Rego policy from a GitHub event payload.
    Currently supports pull_request and push with minimal fields.
    """
    repo_environments = repo_environments or ["production", "staging", "development"]

    environment = "production"
    ref = payload.get("ref") or ""

    if event_name == "pull_request":
        pr = payload.get("pull_request", {})
        ref = pr.get("head", {}).get("ref", "")
        base_ref = pr.get("base", {}).get("ref", "")
        # Heuristic: main -> production, develop -> staging, else development
        if base_ref == "main":
            environment = "production"
        elif base_ref in ("develop", "development", "dev"):
            environment = "staging"
        else:
            environment = "development"

        title = pr.get("title", "")
        body = pr.get("body", "")
        rules = (
            repo_policy.get("policy", {})
            .get("environments", {})
            .get(environment, {})
            .get("rules", {})
        )
        ticket_pattern = rules.get("ticket_pattern", "^.*$")
        ticket_refs = _extract_ticket_refs(title, body, ticket_pattern)
        approvers = _collect_pr_approvers(pr)
        checks_tests = payload.get("checks", {}).get("tests", None)
        if checks_tests is None:
            # Default to False if unknown
            checks_tests = False
        signed_off = payload.get("signed_off", False)
        deployments_today = payload.get("deployments_today", 0)

    elif event_name == "push":
        ref = payload.get("ref", "")
        if ref == "refs/heads/main":
            environment = "production"
        elif ref in ("refs/heads/develop", "refs/heads/development", "refs/heads/dev"):
            environment = "staging"
        else:
            environment = "development"
        # Push events usually do not carry reviews; set minimal defaults
        rules = (
            repo_policy.get("policy", {})
            .get("environments", {})
            .get(environment, {})
            .get("rules", {})
        )
        ticket_pattern = rules.get("ticket_pattern", "^.*$")
        commits = payload.get("commits", []) or []
        title = commits[0].get("message", "") if commits else ""
        body = "\n".join([c.get("message", "") for c in commits])
        ticket_refs = _extract_ticket_refs(title, body, ticket_pattern)
        approvers = []
        checks_tests = False
        signed_off = False
        deployments_today = 0
    else:
        # Fallback minimal mapping
        rules = (
            repo_policy.get("policy", {})
            .get("environments", {})
            .get("production", {})
            .get("rules", {})
        )
        ticket_pattern = rules.get("ticket_pattern", "^.*$")
        ticket_refs = []
        approvers = []
        checks_tests = False
        signed_off = False
        deployments_today = 0

    input_doc: Dict[str, Any] = {
        "environment": environment,
        "ref": ref,
        "repo_policy": repo_policy,
        "repo_environments": repo_environments,
        "workflow_meta": {
            "ticket_refs": ticket_refs,
            "approvers": approvers,
            "checks": {
                "tests": bool(checks_tests),
            },
            "signed_off": bool(signed_off),
            "deployments_today": int(deployments_today),
        },
    }
    return input_doc


def process_event(
    wasm_path: str,
    event_name: str,
    payload: Dict[str, Any],
    repo_policy: Dict[str, Any],
    entry_allow: str = "data.github.deploy.allow",
    entry_viol: str = "data.github.deploy.violations",
) -> Dict[str, Any]:
    """Evaluate policy for a GitHub event and return a decision object."""
    input_doc = build_policy_input(event_name, payload, repo_policy)

    try:
        allow_res = evaluate_policy(wasm_path, input_doc, entrypoint=entry_allow)
        viol_res = evaluate_policy(wasm_path, input_doc, entrypoint=entry_viol)
    except PolicyError as e:
        return {"allow": False, "message": f"Policy evaluation error: {e}", "violations": [str(e)]}

    allow = bool(allow_res) if isinstance(allow_res, bool) else bool(allow_res.get("result", allow_res))
    violations: List[str] = []
    if isinstance(viol_res, list):
        violations = [str(v) for v in viol_res]
    elif isinstance(viol_res, dict) and "result" in viol_res:
        r = viol_res["result"]
        if isinstance(r, list):
            violations = [str(v) for v in r]
        elif r:
            violations = [str(r)]

    return {
        "allow": allow and not violations,
        "message": "Policy passed" if (allow and not violations) else "Policy failed",
        "violations": violations,
    }
