from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any, Dict, Optional, Tuple, List

from . import __version__
from .core import PolicyError, PolicyRegistry


KNOWN_CMDS = {"allow", "violations", "decision", "evaluate", "version"}


def _load_input(input_path: Optional[str]) -> Dict[str, Any]:
    if input_path:
        if not os.path.exists(input_path):
            raise PolicyError(f"Input not found: {input_path}")
        with open(input_path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    data = sys.stdin.read()
    if not data.strip():
        return {}
    try:
        return json.loads(data)
    except Exception as e:
        raise PolicyError(f"Failed to parse JSON from stdin: {e}") from e


def _split_argv(argv: List[str]) -> Tuple[List[str], str, List[str]]:
    """
    Split argv into (left_of_cmd, cmd, right_of_cmd).
    cmd is one of KNOWN_CMDS. If not found, raise.
    """
    for i, tok in enumerate(argv):
        if tok in KNOWN_CMDS:
            return argv[:i], tok, argv[i + 1 :]
    raise PolicyError(
        f"No command found. Expected one of: {', '.join(sorted(KNOWN_CMDS))}"
    )


def _globals_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("--index", help="Path to JSON index defining multiple policies.")
    p.add_argument("--artifact", help="Path to .wasm or OPA bundle (.tar/.tar.gz).")
    p.add_argument("--package", help="Default package for the policy (e.g., github.deploy).")
    p.add_argument("--policy", help="Policy name (from index) or synthetic name when no index is used.")
    p.add_argument("--mode", choices=["auto", "wasm", "cli"], help="Backend mode.")
    p.add_argument("-i", "--input", dest="input_path", help="Path to input JSON (or pass via stdin).")
    return p


def _parse_globals_anywhere(argv_left: List[str], argv_right: List[str]) -> argparse.Namespace:
    """
    Parse global options on both sides of the command and merge (right overrides left).
    Also apply environment variable fallbacks.
    """
    gp = _globals_parser()
    left, _ = gp.parse_known_args(argv_left)
    right, _ = gp.parse_known_args(argv_right)

    def pick(name: str) -> Optional[str]:
        val_r = getattr(right, name, None)
        val_l = getattr(left, name, None)
        if val_r is not None:
            return val_r
        if val_l is not None:
            return val_l
        # env fallback
        env_map = {
            "index": "POLICY_INDEX",
            "artifact": "POLICY_ARTIFACT",
            "package": "POLICY_PACKAGE",
            "policy": "POLICY_NAME",
            "mode": "POLICY_MODE",
            "input_path": "POLICY_INPUT",
        }
        env_name = env_map.get(name)
        return os.environ.get(env_name) if env_name else None

    ns = argparse.Namespace(
        index=pick("index"),
        artifact=pick("artifact"),
        package=pick("package"),
        policy=pick("policy"),
        mode=pick("mode") or "auto",
        input_path=pick("input_path"),
    )
    return ns


def _parse_command_specific(cmd: str, argv_right: List[str]) -> argparse.Namespace:
    """
    Parse command-specific options only from the right side (after the command).
    """
    sp = argparse.ArgumentParser(add_help=True)
    if cmd == "evaluate":
        sp.add_argument("--entrypoint", required=True, help="Full entrypoint, e.g., data.pkg.rule")
    # others don't need extra args
    args, _ = sp.parse_known_args(argv_right)
    return args


def _build_registry(args) -> PolicyRegistry:
    reg = PolicyRegistry()
    if args.command == "version":
        return reg
    if args.index:
        reg.load_from_index(args.index)
        return reg
    if not args.artifact or not args.package:
        raise PolicyError("When not using --index, you must provide --artifact and --package.")
    name = args.policy or "default"
    reg.register(name=name, artifact=args.artifact, package=args.package, mode=args.mode)
    return reg


def main() -> int:
    # Allow mixing global options before/after the command.
    argv = sys.argv[1:]
    try:
        left, cmd, right = _split_argv(argv)
    except PolicyError as e:
        # Fallback to a simple help if no command provided
        if not argv or any(a in ("-h", "--help") for a in argv):
            print(
                "Usage: governant [global options] {allow|violations|decision|evaluate|version} [command options]\n"
                "Try: governant version"
            )
            return 0
        print(f"ERROR: {e}", file=sys.stderr)
        return 2

    # Parse globals from both sides and merge
    g = _parse_globals_anywhere(left, right)
    g.command = cmd

    # Parse command-specific (right side)
    cs = _parse_command_specific(cmd, right)
    if cmd == "evaluate":
        g.entrypoint = cs.entrypoint  # type: ignore[attr-defined]

    try:
        if g.command == "version":
            print(__version__)
            return 0

        reg = _build_registry(g)
        input_doc = _load_input(g.input_path)
        policy_name = g.policy or ("default" if not g.index else None)

        if g.index and not g.policy:
            raise PolicyError("When using --index, you must specify --policy <name>.")

        if g.command == "allow":
            res = reg.allow(policy_name, input_doc)  # type: ignore[arg-type]
        elif g.command == "violations":
            res = reg.violations(policy_name, input_doc)  # type: ignore[arg-type]
        elif g.command == "decision":
            res = reg.decision(policy_name, input_doc)  # type: ignore[arg-type]
        elif g.command == "evaluate":
            res = reg.evaluate(policy_name, g.entrypoint, input_doc)  # type: ignore[arg-type]
        else:
            raise PolicyError(f"Unknown command: {g.command}")

        print(json.dumps(res, ensure_ascii=False))
        return 0

    except PolicyError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    except Exception as e:
        print(f"UNEXPECTED ERROR: {e}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
