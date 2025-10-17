#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
# Usa siempre el MISMO intérprete para instalar y ejecutar.
# Si usas venv: export PYTHON_BIN=".venv/bin/python"
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

# Env overrides
export POLICY_ARTIFACT="${POLICY_ARTIFACT:-$WASM_BUNDLE}"
export POLICY_PACKAGE="${POLICY_PACKAGE:-github_env_protect}"  # <-- cámbialo si tu package es otro

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

if [[ ! -f "$POLICY_ARTIFACT" ]]; then
  echo "❌ Error: WASM/bundle not found at $POLICY_ARTIFACT"
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

# Parse JSON from stdin with Python (no extra deps)
json_get_bool() {
  $PYTHON_BIN - "$@" <<'PY'
import json,sys
data=json.load(sys.stdin)
if isinstance(data,bool): print(1 if data else 0)
elif isinstance(data,dict) and "allow" in data and isinstance(data["allow"],bool): print(1 if data["allow"] else 0)
else: print(1 if data else 0)
PY
}

json_list_is_empty() {
  $PYTHON_BIN - "$@" <<'PY'
import json,sys
data=json.load(sys.stdin)
if isinstance(data,list): print(1 if len(data)==0 else 0)
elif isinstance(data,dict) and "violations" in data and isinstance(data["violations"],list): print(1 if len(data["violations"])==0 else 0)
else: print(0)
PY
}

# --- Show version (CLI real) ---
run_command $PYTHON_BIN -m governant.cli version

# 1) allow (estricto: debe ser true)
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
if [[ "$allow_bool" != "1" ]]; then
  echo "❌ allow returned false (strict)"
  exit 3
fi

# 2) violations (esperamos lista no vacía en el inválido; no paramos el script)
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
  echo "⚠️  violations is empty; esperaba violaciones en el input inválido."
fi

# 3) evaluate de un entrypoint arbitrario
echo -e "\n🔎 Evaluating arbitrary entrypoint…"
run_command $PYTHON_BIN -m governant.cli \
  --artifact "$POLICY_ARTIFACT" \
  --package "$POLICY_PACKAGE" \
  evaluate --entrypoint "data.${POLICY_PACKAGE}.allow" -i "$VALID_INPUT"

echo -e "\n🎉 All commands completed!"
