from __future__ import annotations

import argparse
import json
import os
import sys
from json import JSONDecodeError
from typing import Any, Dict, Optional

from .main import PolicyEngine, PolicyError, DEFAULT_ARTIFACT, load_json


def _printer(fmt: str):
    def pretty(obj: Any):
        if fmt == "json":
            print(json.dumps(obj, ensure_ascii=False))
        else:
            print(json.dumps(obj, indent=2, ensure_ascii=False))
    return pretty


def _exit_for_allow(allowed: bool, strict_exit: bool) -> int:
    if not strict_exit:
        return 0
    # Conventional non-zero on deny for CI
    return 0 if allowed else 2


def _read_input(path: str) -> Dict[str, Any]:
    if path == "-":
        try:
            return json.load(sys.stdin)
        except JSONDecodeError as e:
            raise PolicyError(f"Invalid JSON from STDIN: {e}") from e
    try:
        return load_json(path)
    except FileNotFoundError:
        raise PolicyError(f"Input file not found: {path}")
    except JSONDecodeError as e:
        raise PolicyError(f"Invalid JSON in {path}: {e}") from e


def cmd_allow(args: argparse.Namespace) -> int:
    try:
        eng = PolicyEngine(args.artifact)
        input_doc: Dict[str, Any] = _read_input(args.input)
        allowed = eng.allow(input_doc)
        if not args.quiet:
            if args.output == "bool":
                print("true" if allowed else "false")
            else:
                _printer(args.format)({"allow": allowed})
        return _exit_for_allow(allowed, args.strict_exit)
    except PolicyError as e:
        print(f"[policy][error] {e} (artifact: {args.artifact})", file=sys.stderr)
        return 1


def cmd_violations(args: argparse.Namespace) -> int:
    try:
        eng = PolicyEngine(args.artifact)
        input_doc: Dict[str, Any] = _read_input(args.input)
        v = eng.violations(input_doc)
        if not args.quiet:
            _printer(args.format)({"violations": v})
        # exit non-zero if there are violations and strict-exit requested
        if args.strict_exit and len(v) > 0:
            return 3
        return 0
    except PolicyError as e:
        print(f"[policy][error] {e} (artifact: {args.artifact})", file=sys.stderr)
        return 1


def cmd_eval(args: argparse.Namespace) -> int:
    try:
        eng = PolicyEngine(args.artifact)
        input_doc: Dict[str, Any] = _read_input(args.input)
        res = eng.evaluate(args.entrypoint, input_doc).raw
        if not args.quiet:
            _printer(args.format)(res)
        return 0
    except PolicyError as e:
        print(f"[policy][error] {e} (artifact: {args.artifact})", file=sys.stderr)
        return 1


def cmd_version(args: argparse.Namespace) -> int:
    try:
        from opa_wasm import __version__ as opa_ver  # type: ignore
    except Exception:
        opa_ver = "unavailable"
    info = {
        "cli": "policy",
        "opa_wasm": opa_ver,
        "artifact": args.artifact,
    }
    print(json.dumps(info, indent=2, ensure_ascii=False))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="policy",
        description="CLI for evaluating OPA (WASM bundle) policies",
    )

    default_artifact = os.environ.get("POLICY_ARTIFACT", DEFAULT_ARTIFACT)
    p.add_argument(
        "--artifact",
        default=default_artifact,
        help=f"Path to bundle (.tar.gz). Default: $POLICY_ARTIFACT or {DEFAULT_ARTIFACT}",
    )
    p.add_argument(
        "--format",
        choices=["pretty", "json"],
        default="pretty",
        help="Output format (pretty JSON or compact JSON).",
    )
    p.add_argument(
        "--quiet",
        action="store_true",
        help="Suppress normal output; only use exit codes (good for CI).",
    )

    sub = p.add_subparsers(dest="cmd", required=True)

    # version
    sp = sub.add_parser("version", help="Print versions (cli and opa-wasm)")
    sp.set_defaults(func=cmd_version)

    # allow
    sp = sub.add_parser("allow", help="Evaluate data.github.deploy.allow → bool")
    sp.add_argument("-i", "--input", required=True, help="Path to input JSON or '-' (STDIN)")
    sp.add_argument(
        "--output",
        choices=["json", "bool"],
        default="json",
        help="Output 'bool' (true/false) or JSON {'allow': ...}",
    )
    sp.add_argument(
        "--strict-exit",
        action="store_true",
        help="Exit 2 when deny (useful for CI gates).",
    )
    sp.set_defaults(func=cmd_allow)

    # violations
    sp = sub.add_parser("violations", help="Evaluate data.github.deploy.violations → list")
    sp.add_argument("-i", "--input", required=True, help="Path to input JSON or '-' (STDIN)")
    sp.add_argument(
        "--strict-exit",
        action="store_true",
        help="Exit 3 when there are violations (useful for CI gates).",
    )
    sp.set_defaults(func=cmd_violations)

    # eval (arbitrary entrypoint)
    sp = sub.add_parser("eval", help="Evaluate arbitrary entrypoint")
    sp.add_argument("-i", "--input", required=True, help="Path to input JSON or '-' (STDIN)")
    sp.add_argument(
        "-e",
        "--entrypoint",
        required=True,
        help="Entrypoint (e.g., data.github.deploy.allow or github/deploy/allow)",
    )
    sp.set_defaults(func=cmd_eval)

    return p


def main(argv: Optional[list[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
