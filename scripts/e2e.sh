#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

note() { echo "[E2E] $*"; }
ok() { echo "[E2E][OK] $*"; }
fail() { echo "[E2E][FAIL] $*" >&2; exit 1; }

# 1) Validate Rego
note "Validating Rego syntax & checks"
chmod +x scripts/*.sh || true
./scripts/validate_rego.sh

# 2) Compile to Wasm (outputs ./.compile/*.wasm and .tar.gz)
note "Compiling policy to Wasm"
./scripts/compile_policy.sh

# 3) Quick OPA CLI evaluation (bundle)
if command -v opa >/dev/null 2>&1; then
  note "OPA CLI: evaluating allow on production-valid.json"
  opa eval \
    --entrypoint data.github.deploy.allow \
    --bundle .compile/github-release.tar.gz \
    --input test-inputs/production-valid.json \
    true | sed -e 's/^/[OPA] /'

  note "OPA CLI: evaluating violations on production-invalid.json"
  opa eval \
    --entrypoint data.github.deploy.violations \
    --bundle .compile/github-release.tar.gz \
    --input test-inputs/production-invalid.json \
    true | sed -e 's/^/[OPA] /'
else
  note "OPA CLI not found; skipping OPA CLI checks"
fi

# 4) Python core CLI (prefer opa for robustness)
if command -v python >/dev/null 2>&1; then
  note "Installing project editable and opa-wasm if needed (uv recommended)"
  if command -v uv >/dev/null 2>&1; then
    uv pip install -e . >/dev/null
    uv pip install "opa-wasm[cranelift]" >/dev/null || true
  else
    python -m pip install -e . >/dev/null
    python -m pip install "opa-wasm[cranelift]" >/dev/null || true
  fi

  note "Core CLI: allow on production-valid.json (bundle, prefer opa)"
  python -m opawasm \
    .compile/github-release.tar.gz \
    test-inputs/production-valid.json \
    --prefer opa \
    --entrypoint data.github.deploy.allow \
    --format pretty
else
  note "Python not found; skipping Python CLIs"
fi

# 5) GitHub adapter CLI against sample events
if command -v python >/dev/null 2>&1; then
  note "ghprotect: PR valid -> expect ALLOW"
  python -m ghprotect \
    events/pr_valid.json \
    --event-name pull_request \
    --policy .gate/policy.json \
    --wasm .compile/github-release.wasm \
    --output pretty

  note "ghprotect: PR invalid -> expect DENY with violations"
  python -m ghprotect \
    events/pr_invalid.json \
    --event-name pull_request \
    --policy .gate/policy.json \
    --wasm .compile/github-release.wasm \
    --output pretty
fi

ok "E2E completed"
