from __future__ import annotations

import inspect
import json
import os
from dataclasses import dataclass
from typing import Any, Dict, List, Optional
import atexit
import tarfile
import tempfile
import shutil


# Align default with the bundle you’re generating
DEFAULT_ARTIFACT = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    ".compile",
    "github_env_protect.tar.gz",
)


class PolicyError(Exception):
    pass


def _require_opa_wasm():
    try:
        from opa_wasm import OPAPolicy  # type: ignore
    except Exception as e:
        raise PolicyError(
            "opa-wasm runtime is unavailable. Install it with:\n"
            "  uv pip install 'opa-wasm[cranelift]'\n"
            "or\n"
            "  python -m pip install 'opa-wasm[cranelift]'"
        ) from e
    return OPAPolicy


def _norm_entry(entry: str) -> str:
    """
    Normalize 'entrypoint' to the dot form expected by most Python opa-wasm builds.
    Accepts: 'data.github.deploy.allow' or 'github/deploy/allow' or 'github.deploy.allow'
    Returns: 'data.github.deploy.allow'
    """
    if entry.startswith("data."):
        return entry
    if "/" in entry:
        return "data." + entry.replace("/", ".")
    return "data." + entry


def load_json(path: str) -> Any:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


@dataclass
class EvalResult:
    raw: Any

    def as_bool(self) -> bool:
        """
        Try to coerce the engine's output to a boolean.
        Common OPA patterns:
          - [{'result': True}] or [{'expressions': [{'value': True}]}]
          - True / False (depending on SDK)
        """
        v = self.raw
        # direct boolean
        if isinstance(v, bool):
            return v
        # list with dict payloads
        if isinstance(v, list) and v:
            item = v[0]
            if isinstance(item, dict):
                # opa CLI-like shape
                if "result" in item and isinstance(item["result"], bool):
                    return item["result"]
                # some runtimes return expressions: [{ 'expressions': [{'value': True}]}]
                exprs = item.get("expressions")
                if isinstance(exprs, list) and exprs and isinstance(exprs[0], dict):
                    val = exprs[0].get("value")
                    if isinstance(val, bool):
                        return val
        # fallback: truthiness
        return bool(v)

    def as_list(self) -> List[Any]:
        if isinstance(self.raw, list):
            return self.raw
        return [self.raw]


class PolicyEngine:
    """
    Thin wrapper around opa-wasm to load the bundle once and expose
    high-level helpers for your two entrypoints:
      - data.github.deploy.allow         -> bool
      - data.github.deploy.violations    -> list
    """

    def __init__(self, artifact: Optional[str] = None) -> None:
        self.artifact = artifact or DEFAULT_ARTIFACT
        if not os.path.isfile(self.artifact):
            raise PolicyError(f"Bundle not found: {self.artifact}")
        OPAPolicy = _require_opa_wasm()
        self._policy = self._load_policy(OPAPolicy, self.artifact)

    def _load_policy(self, OPAPolicy, artifact: str):
        """Support multiple opa-wasm Python APIs across versions."""
        # Heuristic: bundle vs single wasm
        is_bundle = artifact.endswith((".tar.gz", ".tgz", ".tar", ".zip"))

        # 1) Prefer classmethods if available
        if is_bundle and hasattr(OPAPolicy, "from_bundle"):
            return OPAPolicy.from_bundle(artifact)
        if (not is_bundle) and hasattr(OPAPolicy, "from_wasm_file"):
            return OPAPolicy.from_wasm_file(artifact)

        # 2) Fall back to constructor kwargs based on signature
        params = inspect.signature(OPAPolicy.__init__).parameters
        def can(name: str) -> bool:
            return name in params

        # If this is a bundle but the runtime doesn't expose 'from_bundle',
        # try constructor kwargs that accept a bundle-like arg. Otherwise,
        # extract the first .wasm file from the archive and initialize the
        # policy with the extracted wasm file (some runtime versions expect a
        # single wasm path like 'wasm_path' or 'wasm').
        if is_bundle:
            if can("from_bundle"):
                return OPAPolicy.from_bundle(artifact)
            if can("bundle_path"):
                return OPAPolicy(bundle_path=artifact)
            if can("path"):
                return OPAPolicy(path=artifact)
            if can("bundle"):
                return OPAPolicy(bundle=artifact)
            # Fall back: extract a .wasm from the bundle to a temp file
            try:
                tmp_dir = tempfile.mkdtemp(prefix="opawasm_bundle_")
                atexit.register(lambda: shutil.rmtree(tmp_dir, ignore_errors=True))
                # Support tar/tgz archives
                with tarfile.open(artifact, "r:*") as tf:
                    wasm_member = None
                    for m in tf.getmembers():
                        if m.name.endswith(".wasm"):
                            wasm_member = m
                            break
                    if wasm_member is None:
                        raise PolicyError("No .wasm file found inside bundle")
                    # tf.extract returns None in some Python versions; build path
                    tf.extract(wasm_member, path=tmp_dir)
                    wasm_path = os.path.join(tmp_dir, wasm_member.name)
            except Exception as e:
                raise PolicyError(f"Failed to extract wasm from bundle: {e}") from e

            # Now initialize OPAPolicy using a wasm path param if available
            if can("wasm_path"):
                return OPAPolicy(wasm_path=wasm_path)
            if can("wasm"):
                return OPAPolicy(wasm=wasm_path)
            if can("path"):
                return OPAPolicy(path=wasm_path)
        else:
            if can("path"):
                return OPAPolicy(path=artifact)
            if can("wasm"):
                return OPAPolicy(wasm=artifact)

        # 3) No compatible signature found
        raise PolicyError(
            "Cannot initialize OPAPolicy with the provided artifact. "
            f"Constructor parameters: {list(params.keys())}. "
            "Tried from_bundle/from_wasm_file and common kwargs "
            "(bundle_path, path, bundle, wasm)."
        )

    def evaluate(self, entrypoint: str, input_doc: Dict[str, Any]) -> EvalResult:
        ep = _norm_entry(entrypoint)
        try:
            out = self._policy.evaluate(ep, input_doc)
        except TypeError:
            # Older builds may have reversed signature
            out = self._policy.evaluate(input_doc, entrypoint=ep)
        return EvalResult(out)

    # Convenience helpers for your common entrypoints
    def allow(self, input_doc: Dict[str, Any]) -> bool:
        return self.evaluate("data.github.deploy.allow", input_doc).as_bool()

    def violations(self, input_doc: Dict[str, Any]) -> List[Any]:
        res = self.evaluate("data.github.deploy.violations", input_doc).raw
        # Most policies return a list (possibly []), but normalize anyway:
        return res if isinstance(res, list) else [res]
