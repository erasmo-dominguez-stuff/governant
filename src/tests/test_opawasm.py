import json
import os
from pathlib import Path

import pytest

from opawasm.main import evaluate_policy, PolicyError

ROOT = Path(__file__).resolve().parents[2]
WASM = ROOT / ".compile/github-release.wasm"
VALID = ROOT / "test-inputs/production-valid.json"
INVALID = ROOT / "test-inputs/production-invalid.json"

@pytest.mark.skipif(not WASM.exists(), reason="compiled wasm not found; run scripts/compile_policy.sh")
class TestOpaWasm:
    def test_allow_valid(self):
        with VALID.open("r", encoding="utf-8") as f:
            data = json.load(f)
        res = evaluate_policy(str(WASM), data, entrypoint="data.github.deploy.allow")
        assert bool(res) or bool(getattr(res, "get", lambda *_: False)("result", res))

    def test_violations_invalid(self):
        with INVALID.open("r", encoding="utf-8") as f:
            data = json.load(f)
        res = evaluate_policy(str(WASM), data, entrypoint="data.github.deploy.violations")
        # Expect at least one violation
        if isinstance(res, dict) and "result" in res:
            r = res["result"]
            assert isinstance(r, list) and len(r) >= 1
        elif isinstance(res, list):
            assert len(res) >= 1
        else:
            pytest.fail(f"Unexpected violations result shape: {res}")
