#!/usr/bin/env python3
"""Simple hardcoded example showing how to call PolicyEngine directly.

Usage:
  python3 examples/run_policy_hardcoded.py

This script prefers the `.governant/` policy directory when present (useful for
local development). It demonstrates evaluating `allow` and `violations` for
the `github.deploy` package. Adjust `default_pkg` or `input_doc` to test other
entrypoints or policies.
"""
from __future__ import annotations

import json
import os
import sys

from governant.core import PolicyEngine, PolicyError


def locate_artifact(root: str) -> str:
    gate = os.path.join(root, ".governant")
    bundle = os.path.join(root, ".compile", "github_env_protect.tar.gz")
    if os.path.isdir(gate):
        return gate
    if os.path.isfile(bundle):
        return bundle
    raise FileNotFoundError("No policy artifact found (.governant/ or .compile/*.tar.gz)")


def load_policy_json(root: str) -> dict:
    # Some policies expect the input to include the repo policy JSON under
    # `input.repo_policy` — load the file if present to make the demo realistic.
    path = os.path.join(root, ".governant", "policies", "github_env_protect_policy.json")
    if os.path.isfile(path):
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    return {}


def main() -> int:
    repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    try:
        artifact = locate_artifact(repo_root)
    except FileNotFoundError as e:
        print("ERROR:", e, file=sys.stderr)
        return 2

    # Choose the package you want to evaluate. The repository contains
    # `github.deploy` (in github_env_protect.rego) and `github.pullrequest`.
    default_pkg = "github.deploy"

    # Build a hardcoded input similar to what the Rego policy expects.
    repo_policy = load_policy_json(repo_root)

    input_doc = {
        "environment": "production",
        "ref": "refs/heads/main",
        "repo_environments": ["production"],
        "workflow_meta": {
            "approvers": ["alice", "bob"],
            "checks": {"tests": True},
            "signed_off": True,
            "deployments_today": 1,
        },
        "repo_policy": repo_policy,
    }

    print(f"Using artifact: {artifact}")
    print(f"Default package: {default_pkg}")

    try:
        engine = PolicyEngine(artifact=artifact, default_pkg=default_pkg, mode="auto")
    except PolicyError as e:
        print("Failed to initialize policy engine:", e, file=sys.stderr)
        return 3

    try:
        allow = engine.allow(input_doc)
        violations = engine.violations(input_doc)
    except PolicyError as e:
        print("Policy evaluation error:", e, file=sys.stderr)
        return 4

    print("\nPolicy result:")
    print("allow:", allow)
    print("violations:", json.dumps(violations, indent=2, ensure_ascii=False))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
