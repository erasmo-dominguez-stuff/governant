from __future__ import annotations

"""
PolicyEngine & PolicyRegistry — Execute compiled Rego (WASM or bundle) from Python.

Backends:
- WASM via `opa-wasm` (optional dependency).
- CLI via `opa eval` (requires `opa` binary in PATH).

Convenience:
- evaluate(entrypoint, input)
- allow(input)        -> bool (data.<pkg>.allow)
- violations(input)   -> list (data.<pkg>.violations)
- decision(input)     -> {"allow": bool, "violations": list}
- PolicyRegistry for multiple named policies.
"""

import json
import os
import shutil
import subprocess
import tarfile
import tempfile
from dataclasses import dataclass
from typing import Any, Dict, List, Optional

Json = Dict[str, Any]


class PolicyError(Exception):
    """Raised for errors when evaluating a policy."""


def _ensure_opa_available() -> None:
    if shutil.which("opa") is None:
        raise PolicyError("OPA CLI not found in PATH. Install OPA or add it to PATH.")


def _write_temp_json(obj: Any) -> str:
    fd, tmp = tempfile.mkstemp(suffix=".json")
    os.close(fd)
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(obj, fh)
    return tmp


def _wrap_wasm_as_bundle(path_to_wasm: str) -> str:
    """
    Create a temporary OPA bundle (.tar.gz) containing the given policy.wasm.
    Returns the path to the temp bundle.
    """
    fd, tmp = tempfile.mkstemp(suffix=".tar.gz")
    os.close(fd)
    try:
        with tarfile.open(tmp, "w:gz") as tf:
            tf.add(path_to_wasm, arcname="policy.wasm")
    except Exception as e:
        try:
            os.remove(tmp)
        except Exception:
            pass
        raise PolicyError(f"Failed to build temporary bundle from wasm: {e}") from e
    return tmp


def _extract_opa_json_value(parsed: Dict[str, Any]) -> Any:
    """
    OPA --format=json yields structures like:
      {"result":[{"expressions":[{"value":<VAL>, ...}]}]}
    Extract <VAL> robustly; fallback to returning parsed if unknown.
    """
    if not isinstance(parsed, dict):
        return parsed
    result = parsed.get("result")
    if isinstance(result, list) and result:
        first = result[0]
        if isinstance(first, dict):
            exprs = first.get("expressions")
            if isinstance(exprs, list) and exprs:
                v = exprs[0].get("value") if isinstance(exprs[0], dict) else None
                if v is not None:
                    return v
    if "result" in parsed and not isinstance(parsed["result"], list):
        return parsed["result"]
    return parsed


# -------------------------
# Backends
# -------------------------

class _Backend:
    def evaluate(self, entrypoint: str, input_doc: Json) -> Any:
        raise NotImplementedError


class _WasmBackend(_Backend):
    """
    Execute policy.wasm via opa-wasm (no subprocess).
    """
    def __init__(self, artifact: str):
        try:
            from opa_wasm import OPARuntime  # type: ignore
        except Exception as e:
            raise PolicyError(
                "opa-wasm is not installed or failed to import. "
                "Install with `pip install opa-wasm` or use CLI backend."
            ) from e

        if not os.path.exists(artifact):
            raise PolicyError(f"Artifact not found: {artifact}")
        if not artifact.endswith(".wasm"):
            raise PolicyError("WASM backend requires a .wasm artifact")

        with open(artifact, "rb") as f:
            wasm_bytes = f.read()

        self._runtime = OPARuntime(wasm_bytes)

    def evaluate(self, entrypoint: str, input_doc: Json) -> Any:
        if not entrypoint.startswith("data."):
            raise PolicyError("Entrypoint must start with 'data.'")
        return self._runtime.evaluate(input_doc, entrypoint=entrypoint)


class _CliBackend(_Backend):
    """
    Execute via 'opa eval --format json --bundle <bundle> -i <input> <entrypoint>'
    Works with bundles and .wasm (we wrap wasm into a temp bundle).
    """
    def __init__(self, artifact: str):
        if not os.path.exists(artifact):
            raise PolicyError(f"Artifact not found: {artifact}")
        _ensure_opa_available()
        self.artifact = artifact

    def evaluate(self, entrypoint: str, input_doc: Json) -> Any:
        if not entrypoint.startswith("data."):
            raise PolicyError("Entrypoint must start with 'data.'")

        bundle_path = self.artifact
        tmp_bundle: Optional[str] = None
        if self.artifact.endswith(".wasm"):
            bundle_path = _wrap_wasm_as_bundle(self.artifact)
            tmp_bundle = bundle_path

        input_tmp = _write_temp_json(input_doc)
        try:
            cmd = [
                "opa", "eval",
                "--format", "json",
                "--bundle", bundle_path,
                "-i", input_tmp,
                entrypoint,
            ]
            proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            out = proc.stdout.decode("utf-8", errors="replace").strip()
            err = proc.stderr.decode("utf-8", errors="replace").strip()

            if proc.returncode != 0:
                if out:
                    try:
                        j = json.loads(out)
                        if isinstance(j, dict) and "errors" in j:
                            msgs = ", ".join(e.get("message", str(e)) for e in j.get("errors", []))
                            raise PolicyError(f"opa eval error: {msgs}")
                    except Exception:
                        pass
                msg = err or out or f"opa exited with code {proc.returncode}"
                raise PolicyError(msg)

            parsed = json.loads(out) if out else {}
            return _extract_opa_json_value(parsed)

        finally:
            try:
                os.remove(input_tmp)
            except Exception:
                pass
            if tmp_bundle:
                try:
                    os.remove(tmp_bundle)
                except Exception:
                    pass


# -------------------------
# Public API
# -------------------------

@dataclass
class PolicySpec:
    name: str
    artifact: str
    package: str  # e.g., "github.deploy"
    mode: str = "auto"  # "auto" | "wasm" | "cli"


class PolicyEngine:
    """
    High-level wrapper with convenience methods. Defaults to the package you provide.
    """
    def __init__(self, artifact: str, default_pkg: str, mode: str = "auto"):
        self.artifact = artifact
        self.default_pkg = default_pkg
        self._backend = self._select_backend(artifact, mode)

    @staticmethod
    def _select_backend(artifact: str, mode: str) -> _Backend:
        mode = mode.lower()
        if mode not in ("auto", "wasm", "cli"):
            raise PolicyError("mode must be one of: auto|wasm|cli")

        if mode == "wasm":
            return _WasmBackend(artifact)
        if mode == "cli":
            return _CliBackend(artifact)

        if artifact.endswith(".wasm"):
            try:
                return _WasmBackend(artifact)
            except PolicyError:
                return _CliBackend(artifact)
        return _CliBackend(artifact)

    def _ep(self, rule: str) -> str:
        return f"data.{self.default_pkg}.{rule}"

    def evaluate(self, entrypoint: str, input_doc: Json) -> Any:
        return self._backend.evaluate(entrypoint, input_doc)

    def allow(self, input_doc: Json) -> bool:
        val = self._backend.evaluate(self._ep("allow"), input_doc)
        return bool(val)

    def violations(self, input_doc: Json) -> List[Any]:
        val = self._backend.evaluate(self._ep("violations"), input_doc)
        if isinstance(val, list):
            return val
        return [val] if val is not None else []

    def decision(self, input_doc: Json) -> Dict[str, Any]:
        return {"allow": self.allow(input_doc), "violations": self.violations(input_doc)}


class PolicyRegistry:
    """
    Manages multiple named policies. Useful for CLIs or services.
    """
    def __init__(self):
        self._engines: Dict[str, PolicyEngine] = {}

    def register(self, name: str, artifact: str, package: str, mode: str = "auto") -> None:
        if name in self._engines:
            raise PolicyError(f"Policy already registered: {name}")
        self._engines[name] = PolicyEngine(artifact=artifact, default_pkg=package, mode=mode)

    def load_from_index(self, index_path: str) -> None:
        """
        Index JSON schema:
        [
          {"name":"deploy","artifact":"./policy.wasm","package":"github.deploy","mode":"auto"},
          {"name":"release","artifact":"./bundle.tar.gz","package":"acme.release","mode":"cli"}
        ]
        """
        if not os.path.exists(index_path):
            raise PolicyError(f"Index not found: {index_path}")
        with open(index_path, "r", encoding="utf-8") as fh:
            items = json.load(fh)
        if not isinstance(items, list):
            raise PolicyError("Index JSON must be a list of objects")
        for it in items:
            name = it["name"]
            artifact = it["artifact"]
            package = it["package"]
            mode = it.get("mode", "auto")
            self.register(name, artifact, package, mode)

    def get(self, name: str) -> PolicyEngine:
        if name not in self._engines:
            raise PolicyError(f"Policy not found: {name}")
        return self._engines[name]

    # convenience passthroughs
    def allow(self, name: str, input_doc: Json) -> bool:
        return self.get(name).allow(input_doc)

    def violations(self, name: str, input_doc: Json) -> List[Any]:
        return self.get(name).violations(input_doc)

    def decision(self, name: str, input_doc: Json) -> Dict[str, Any]:
        return self.get(name).decision(input_doc)

    def evaluate(self, name: str, entrypoint: str, input_doc: Json) -> Any:
        return self.get(name).evaluate(entrypoint, input_doc)
