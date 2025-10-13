import json
from pathlib import Path

import pytest

from ghprotect.handler import process_event

ROOT = Path(__file__).resolve().parents[2]
WASM = ROOT / ".compile/github-release.wasm"
POLICY = ROOT / ".gate/policy.json"
PR_VALID = ROOT / "events/pr_valid.json"
PR_INVALID = ROOT / "events/pr_invalid.json"

@pytest.mark.skipif(not WASM.exists(), reason="compiled wasm not found; run scripts/compile_policy.sh")
class TestGhProtect:
    def _load(self, path: Path):
        with path.open("r", encoding="utf-8") as f:
            return json.load(f)

    def test_pr_valid_allows(self):
        payload = self._load(PR_VALID)
        repo_policy = self._load(POLICY)
        decision = process_event(
            wasm_path=str(WASM),
            event_name="pull_request",
            payload=payload,
            repo_policy=repo_policy,
        )
        assert decision.get("allow") is True
        assert not decision.get("violations")

    def test_pr_invalid_denies(self):
        payload = self._load(PR_INVALID)
        repo_policy = self._load(POLICY)
        decision = process_event(
            wasm_path=str(WASM),
            event_name="pull_request",
            payload=payload,
            repo_policy=repo_policy,
        )
        assert decision.get("allow") is False
        assert decision.get("violations")
