from typing import Any, Dict, Optional

class PolicyError(Exception):
    pass


def evaluate_policy(
    wasm_file: str,
    input_data: Dict[str, Any],
    entrypoint: str = "data.github.deploy.allow",
    data: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Evaluate a compiled OPA Wasm policy using the Python opa-wasm SDK.

    Args:
        wasm_file: Path to the compiled .wasm file.
        input_data: Input document to evaluate.
        entrypoint: Entrypoint to evaluate (e.g., 'data.github.deploy.allow').
        data: Optional data document (equivalent to bundle data.json).

    Returns:
        The evaluation result as a dictionary.

    Raises:
        PolicyError: If opa-wasm is unavailable or evaluation fails.
    """
    try:
        from opa_wasm import OPAPolicy  # type: ignore
    except Exception as e:
        raise PolicyError(
            "opa-wasm runtime is unavailable on this system. Install with: uv pip install 'opa-wasm[cranelift]'"
        ) from e

    def _normalize_entrypoint(ep: str) -> str:
        # Accept either 'data.pkg.rule' or 'pkg/rule'; return slash form
        if ep.startswith("data."):
            return ep[len("data."):].replace(".", "/")
        return ep.replace(".", "/") if "/" not in ep and "." in ep else ep

    try:
        policy = OPAPolicy(wasm_file)
        if data is not None:
            policy.set_data(data)
        try:
            return policy.evaluate(input_data, entrypoint=_normalize_entrypoint(entrypoint))
        except TypeError:
            # Older versions may not support entrypoint kwarg
            return policy.evaluate(input_data)
    except Exception as e:
        raise PolicyError(f"Policy evaluation failed: {e}") from e
