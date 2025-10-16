#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
PYTHON_BIN="${PYTHON_BIN:-python}"
SCRIPT_DIR_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# If the script is inside the repo (e.g., scripts/), walk up until we find pyproject.toml
PROJECT_ROOT="$SCRIPT_DIR_DEFAULT"
while [ "$PROJECT_ROOT" != "/" ] && [ ! -f "$PROJECT_ROOT/pyproject.toml" ]; do
  PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done
if [ "$PROJECT_ROOT" = "/" ]; then
  # Fallback to script dir if pyproject.toml wasn't found
  PROJECT_ROOT="$SCRIPT_DIR_DEFAULT"
fi
# SCRIPT_DIR is intentionally omitted; use PROJECT_ROOT/scripts when needed
VALID_INPUT="${PROJECT_ROOT}/test-inputs/production-valid.json"
INVALID_INPUT="${PROJECT_ROOT}/test-inputs/production-invalid.json"
WASM_BUNDLE="${PROJECT_ROOT}/.compile/github_env_protect.tar.gz"

# Allow override via env (the CLI also respects POLICY_ARTIFACT)
export POLICY_ARTIFACT="${POLICY_ARTIFACT:-$WASM_BUNDLE}"

echo "🔧 Installing opa-wasm runtime..."
$PYTHON_BIN -m pip install --upgrade pip
$PYTHON_BIN -m pip install 'opa-wasm[cranelift]' --no-cache-dir

echo "📦 Installing package in editable mode..."
$PYTHON_BIN -m pip install -e "${PROJECT_ROOT}"

# --- Sanity checks ---
for f in "$VALID_INPUT" "$INVALID_INPUT"; do
  if [[ ! -f "$f" ]]; then
    echo "❌ Error: Input file not found: $f"
    exit 1
  fi
done

if [[ ! -f "$WASM_BUNDLE" ]]; then
  echo "❌ Error: WASM bundle not found at $WASM_BUNDLE"
  echo "Please run the compile-policy workflow first"
  echo "Looking for bundle candidates in ${PROJECT_ROOT}:"
  find "${PROJECT_ROOT}" \( -name "*.tar.gz" -o -name "*.wasm" \)
  exit 1
fi

# --- Helper to run a command and show output nicely ---
run_command() {
  echo -e "\n🚀 Running: $*"
  if ! output=$("$@" 2>&1); then
    echo -e "❌ Error:\n$output"
    return 1
  else
    echo -e "✅ Output:\n$output"
    return 0
  fi
}

# --- Show versions (debug) ---
run_command $PYTHON_BIN -m opawasm.cli --artifact "$WASM_BUNDLE" version

# 1) Evaluate allow (true/false)
run_command $PYTHON_BIN -m opawasm.cli \
  --artifact "$WASM_BUNDLE" \
  --format pretty \
  allow -i "$VALID_INPUT" --output bool --strict-exit

# 2) List violations
run_command $PYTHON_BIN -m opawasm.cli \
  --artifact "$WASM_BUNDLE" \
  --format pretty \
  violations -i "$INVALID_INPUT" --strict-exit || true
# (|| true) to keep the script going even if exit code 3 is returned for violations

# 3) Evaluate arbitrary entrypoint
run_command $PYTHON_BIN -m opawasm.cli \
  --artifact "$WASM_BUNDLE" \
  --format pretty \
  eval -i "$VALID_INPUT" -e "data.github.deploy.allow"

echo -e "\n🎉 All commands completed!"
