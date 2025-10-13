from __future__ import annotations

import json
import os
from dataclasses import dataclass
from typing import Any, Dict, Iterable, List, Optional, Union


DEFAULT_ARTIFACT = os.path.join(
    os.path.dirname(os.path.dirname(__file__)),
    ".compile",
    "github-release.tar.gz",
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
        # Load bundle (includes policy.wasm, data.json and manifest)
        self._policy = OPAPolicy(bundle=self.artifact)

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
