import argparse
import json
import os
import subprocess
import sys
from typing import Any, Dict, Optional

from .main import evaluate_policy, PolicyError


def _resolve_bundle_target(path: str) -> str:
    """Resolve a path to a suitable OPA --bundle target.

    - If .tar.gz, return as-is.
    - If .wasm, prefer sibling .tar.gz bundle; otherwise, use directory only if it looks like an extracted bundle (has policy.wasm or manifest).
    - If directory, return as-is.
    """
    if os.path.isdir(path):
        return path
    if path.endswith(".tar.gz"):
        return path
    if path.endswith(".wasm"):
        # Prefer sibling tar.gz bundle
        candidate = path[:-5] + ".tar.gz"
        if os.path.exists(candidate):
            return candidate
        # Fallback: parent directory if it contains typical bundle files
        d = os.path.dirname(path)
        if os.path.isdir(d):
            if os.path.exists(os.path.join(d, "policy.wasm")) or os.path.exists(os.path.join(d, ".manifest")):
                return d
        # As last resort, return original (OPA will likely error)
        return path
    return path


def _run_with_opa_cli(wasm_or_bundle: str, input_file: str, entrypoint: str, fmt: str) -> int:
    bundle_target = _resolve_bundle_target(wasm_or_bundle)
    cmd = [
        "opa",
        "eval",
        "--format",
        fmt,
        "--bundle",
        bundle_target,
        "--input",
        input_file,
        entrypoint,
    ]
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    except FileNotFoundError:
        print("Error: 'opa' binary not found in PATH. Please install OPA and try again.", file=sys.stderr)
        return 127

    if proc.returncode != 0:
        print(proc.stderr.strip() or proc.stdout.strip(), file=sys.stderr)
        return proc.returncode

    print(proc.stdout.strip())
    return 0


def _run_with_python(wasm_file: str, input_file: str, entrypoint: str) -> int:
    try:
        with open(input_file, "r") as f:
            data: Dict[str, Any] = json.load(f)
    except Exception as e:
        print(f"Error reading input file: {e}", file=sys.stderr)
        return 2

    try:
        result = evaluate_policy(wasm_file, data, entrypoint=entrypoint)
        print(json.dumps(result, indent=2))
        return 0
    except PolicyError as e:
        print(str(e), file=sys.stderr)
        return 127


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate an OPA policy (compiled to WASM)")
    parser.add_argument("wasm_path", help="Path to the .wasm file or bundle directory")
    parser.add_argument("input_file", help="Path to the input JSON file")
    parser.add_argument(
        "--entrypoint",
        default="data.github.deploy.allow",
        help="Entrypoint to evaluate (e.g., data.github.deploy.allow, data.github.deploy.violations)",
    )
    parser.add_argument(
        "--prefer",
        choices=["python", "opa"],
        default="python",
        help="Prefer 'python' (opa-wasm SDK) or 'opa' (OPA CLI). Falls back automatically if preferred mode unavailable.",
    )
    parser.add_argument(
        "--format",
        default="json",
        choices=["json", "pretty"],
        help="OPA output format when using OPA CLI",
    )
    args = parser.parse_args()

    if args.prefer == "python":
        rc = _run_with_python(args.wasm_path, args.input_file, args.entrypoint)
        if rc == 127:
            rc = _run_with_opa_cli(args.wasm_path, args.input_file, args.entrypoint, args.format)
        sys.exit(rc)
    else:
        rc = _run_with_opa_cli(args.wasm_path, args.input_file, args.entrypoint, args.format)
        if rc == 127:
            rc = _run_with_python(args.wasm_path, args.input_file, args.entrypoint)
        sys.exit(rc)
