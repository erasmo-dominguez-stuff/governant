import argparse
import json
import os
import sys
from typing import Any, Dict

from .handler import process_event


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Evaluate GitHub events against policy using compiled Wasm",
    )
    parser.add_argument("payload", help="Path to GitHub event JSON payload")
    parser.add_argument(
        "--event-name",
        required=True,
        help="GitHub event name (e.g., pull_request, push)",
    )
    parser.add_argument(
        "--policy",
        default=os.path.join(".gate", "policy.json"),
        help="Path to repository policy JSON (default: .gate/policy.json)",
    )
    parser.add_argument(
        "--wasm",
        default=os.path.join(".compile", "github-release.wasm"),
        help="Path to compiled Wasm file (default: .compile/github-release.wasm)",
    )
    parser.add_argument(
        "--entry-allow",
        default="data.github.deploy.allow",
        help="Entrypoint for allow decision",
    )
    parser.add_argument(
        "--entry-violations",
        default="data.github.deploy.violations",
        help="Entrypoint for violations decision",
    )
    parser.add_argument(
        "--output",
        choices=["json", "pretty"],
        default="json",
        help="Output format",
    )

    args = parser.parse_args(argv)

    try:
        with open(args.payload, "r", encoding="utf-8") as f:
            payload: Dict[str, Any] = json.load(f)
        with open(args.policy, "r", encoding="utf-8") as f:
            repo_policy: Dict[str, Any] = json.load(f)
    except Exception as e:
        print(f"Error reading inputs: {e}", file=sys.stderr)
        return 2

    decision = process_event(
        wasm_path=args.wasm,
        event_name=args.event_name,
        payload=payload,
        repo_policy=repo_policy,
        entry_allow=args.entry_allow,
        entry_viol=args.entry_violations,
    )

    if args.output == "pretty":
        status = "ALLOW" if decision.get("allow") else "DENY"
        print(f"Decision: {status}")
        viol = decision.get("violations") or []
        if viol:
            print("Violations:")
            for v in viol:
                print(f"- {v}")
        else:
            print("No violations.")
    else:
        print(json.dumps(decision, indent=2))

    return 0 if decision.get("allow") else 1


if __name__ == "__main__":
    raise SystemExit(main())
