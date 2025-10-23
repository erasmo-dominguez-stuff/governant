#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
# Always use the SAME Python interpreter to install and run.
# If you use a virtual environment, set: export PYTHON_BIN=".venv/bin/python"
PYTHON_BIN="${PYTHON_BIN:-python3}"

SCRIPT_DIR_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Locate project root (where pyproject.toml lives)
PROJECT_ROOT="$SCRIPT_DIR_DEFAULT"
while [ "$PROJECT_ROOT" != "/" ] && [ ! -f "$PROJECT_ROOT/pyproject.toml" ]; do
  PROJECT_ROOT="$(dirname "$PROJECT_ROOT")"
done
if [ "$PROJECT_ROOT" = "/" ]; then
  PROJECT_ROOT="$SCRIPT_DIR_DEFAULT"
fi

VALID_INPUT="${PROJECT_ROOT}/test-inputs/production-valid.json"
INVALID_INPUT="${PROJECT_ROOT}/test-inputs/production-invalid.json"
WASM_BUNDLE="${PROJECT_ROOT}/.compile/github_env_protect.tar.gz"

# Prefer using the Rego source directory (.governant) for local checks because some
# OPA builds may not support executing embedded WASM modules. If .governant exists,
# use it as the artifact (opa accepts --bundle <dir>), otherwise fall back to
# the compiled bundle in .compile.
if [ -d "${PROJECT_ROOT}/.governant" ]; then
  DEFAULT_ARTIFACT="${PROJECT_ROOT}/.governant"
else
  DEFAULT_ARTIFACT="$WASM_BUNDLE"
fi

# Env overrides
export POLICY_ARTIFACT="${POLICY_ARTIFACT:-$DEFAULT_ARTIFACT}"
export POLICY_PACKAGE="${POLICY_PACKAGE:-github.deploy}"

echo "🔧 Ensuring pip is recent…"
$PYTHON_BIN -m pip install --upgrade pip >/dev/null

echo "📦 Installing package in editable mode…"
$PYTHON_BIN -m pip install -e "${PROJECT_ROOT}"

# --- Sanity checks ---
for f in "$VALID_INPUT" "$INVALID_INPUT"; do
  if [[ ! -f "$f" ]]; then
    echo "❌ Error: Input file not found: $f"
    exit 1
  fi
done

if [[ -d "$POLICY_ARTIFACT" ]] || [[ -f "$POLICY_ARTIFACT" ]]; then
  true
else
  echo "❌ Error: Policy artifact not found at $POLICY_ARTIFACT"
  echo "Looking for bundle candidates in ${PROJECT_ROOT}:"
  find "${PROJECT_ROOT}" \( -name "*.tar.gz" -o -name "*.wasm" -o -type d -name ".governant" \)
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

# Parse JSON from stdin with Python (no extra deps)
json_get_bool() {
  $PYTHON_BIN - "$@" <<'PY'
import json,sys
raw = sys.stdin.read()
if not raw or not raw.strip():
  print(0)
  sys.exit(0)
text = raw.strip()
try:
  data = json.loads(text)
except Exception:
  # accept plain 'true'/'false' or other scalars
  t = text.lower()
  if t == 'true':
    print(1)
    sys.exit(0)
  if t == 'false':
    print(0)
    sys.exit(0)
  print(0)
  sys.exit(0)

if isinstance(data, bool):
  print(1 if data else 0)
elif isinstance(data, dict) and "allow" in data and isinstance(data["allow"], bool):
  print(1 if data["allow"] else 0)
else:
  print(1 if data else 0)
PY
}

json_list_is_empty() {
  $PYTHON_BIN - "$@" <<'PY'
import json,sys
raw = sys.stdin.read()
if not raw or not raw.strip():
  print(1)
  sys.exit(0)
text = raw.strip()
try:
  data = json.loads(text)
except Exception:
  # If it's not JSON, assume non-empty
  print(0)
  sys.exit(0)

if isinstance(data, list):
  print(1 if len(data) == 0 else 0)
elif isinstance(data, dict) and "violations" in data and isinstance(data["violations"], list):
  print(1 if len(data["violations"]) == 0 else 0)
else:
  print(0)
PY
}

# --- Show version (real CLI) ---
run_command $PYTHON_BIN -m governant.cli version

# 1) allow (strict: must be true)
echo -e "\n🔎 Checking allow on VALID input (strict)…"
if ! out=$($PYTHON_BIN -m governant.cli \
  --artifact "$POLICY_ARTIFACT" \
  --package "$POLICY_PACKAGE" \
  allow -i "$VALID_INPUT" 2>&1); then
  echo -e "❌ Error:\n$out"
  exit 1
fi
echo -e "✅ Output:\n$out"
allow_bool=$(printf '%s' "$out" | json_get_bool || true)
# Accept either the parsed boolean (1) or the raw 'true' output from the CLI
if [[ "$allow_bool" != "1" ]] && [[ "${out}" != "true" ]]; then
  echo "❌ allow returned false (strict)"
  exit 3
fi

# 2) violations (expect a non-empty list for the invalid input; do not stop the script)
echo -e "\n🔎 Checking violations on INVALID input…"
if ! vout=$($PYTHON_BIN -m governant.cli \
  --artifact "$POLICY_ARTIFACT" \
  --package "$POLICY_PACKAGE" \
  violations -i "$INVALID_INPUT" 2>&1); then
  echo -e "❌ Error:\n$vout"
  exit 1
fi
echo -e "✅ Output:\n$vout"
violations_empty=$(printf '%s' "$vout" | json_list_is_empty || true)
if [[ "$violations_empty" == "1" ]]; then
  echo "⚠️  violations is empty; expected violations for the invalid input."
fi

# 3) evaluate an arbitrary entrypoint
echo -e "\n🔎 Evaluating arbitrary entrypoint…"
run_command $PYTHON_BIN -m governant.cli \
  --artifact "$POLICY_ARTIFACT" \
  --package "$POLICY_PACKAGE" \
  evaluate --entrypoint "data.${POLICY_PACKAGE}.allow" -i "$VALID_INPUT"

echo -e "\n🎉 All commands completed!"
