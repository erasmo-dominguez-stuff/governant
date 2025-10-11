#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# compile_policy.sh
#
# Compiles all Rego (.rego) under ./.gate into WASM bundles for Python.
# Exports two entrypoints per policy:
#   - <package>/allow
#   - <package>/violations
#
# Outputs per policy in: ./compile/<policy-name>/
#   - <policy-name>.wasm
#   - <policy-name>.tar.gz   (OPA bundle)
#   - data.json              (empty placeholder)
#   - <policy-name>.manifest.json (entrypoints & artifacts)
# -----------------------------------------------------------------------------

set -euo pipefail

# Console colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
fail(){ echo -e "${RED}❌ $*${NC}" >&2; exit 1; }
ok(){   echo -e "${GREEN}✔ $*${NC}"; }
warn(){ echo -e "${YELLOW}⚠ $*${NC}"; }
note(){ echo -e "• $*"; }

# Paths (this script lives in scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
GATE_DIR="${REPO_ROOT}/.gate"
OUT_DIR="${REPO_ROOT}/compile"

# --- prereqs ---
command -v opa >/dev/null 2>&1 || fail "OPA not found. Install: https://www.openpolicyagent.org/docs/latest/#running-opa"
VER_LINE="$(opa version 2>/dev/null | head -n1 || true)"; [[ -n "$VER_LINE" ]] && note "Using ${VER_LINE}" || warn "Could not parse OPA version."
[[ -d "${GATE_DIR}" ]] || fail "Directory not found: ${GATE_DIR}"
mkdir -p "${OUT_DIR}"

# Collect rego files
shopt -s nullglob; REGO_FILES=( "${GATE_DIR}"/*.rego ); shopt -u nullglob
[[ ${#REGO_FILES[@]} -gt 0 ]] || fail "No .rego files found in ${GATE_DIR}"

# Parse package from a rego file
parse_package() {
  local file="$1" line
  line="$(grep -m1 -E '^[[:space:]]*package[[:space:]]+[[:alnum:]_.]+' "$file" || true)"
  [[ -z "$line" ]] && { echo ""; return 0; }
  echo "$line" | sed -E 's/^[[:space:]]*package[[:space:]]+([[:alnum:]_.]+).*/\1/'
}

# Warn if rule may be missing
ensure_rule_exists() {
  local file="$1" rulename="$2"
  if ! grep -Eq "^[[:space:]]*${rulename}([[:space:]]|:|$)" "$file"; then
    warn "Rule '${rulename}' not found in $(basename "$file"). Build may fail if truly absent."
  fi
}

build_policy() {
  local rego="$1"
  local base="$(basename "$rego")"
  echo -e "\n${GREEN}🔧 Processing ${base}${NC}"

  local pkg; pkg="$(parse_package "$rego")"
  [[ -n "$pkg" ]] || { warn "No package in ${base}, skipping."; return 0; }
  echo "  Package: ${pkg}"

  echo "  Running opa check…"
  opa check "$rego" || fail "Static check failed for ${base}"

  ensure_rule_exists "$rego" "allow"
  ensure_rule_exists "$rego" "violations"

  # OPA expects entrypoints as slash paths (e.g., github/deploy/allow)
  local pkg_slash="${pkg//./\/}"
  local ENTRY_ALLOW="${pkg_slash}/allow"
  local ENTRY_VIOLATIONS="${pkg_slash}/violations"

  local name="${base%.rego}"
  local out_dir="${OUT_DIR}/${name}"
  rm -rf "${out_dir}"; mkdir -p "${out_dir}"

  local bundle="${out_dir}/${name}.tar.gz"

  echo "  Building WASM bundle…"
  opa build -t wasm -e "${ENTRY_ALLOW}" -e "${ENTRY_VIOLATIONS}" "$rego" -o "$bundle"

  echo "  Extracting bundle…"
  tar -xzf "$bundle" -C "$out_dir"

  [[ -f "${out_dir}/policy.wasm" ]] || fail "policy.wasm missing for ${base}"
  mv "${out_dir}/policy.wasm" "${out_dir}/${name}.wasm"
  [[ -f "${out_dir}/data.json" ]] || echo "{}" > "${out_dir}/data.json"

  cat > "${out_dir}/${name}.manifest.json" <<EOF
{
  "package": "${pkg}",
  "entrypoints": ["${ENTRY_ALLOW}", "${ENTRY_VIOLATIONS}"],
  "artifacts": {
    "wasm": "./${name}.wasm",
    "data": "./data.json",
    "bundle": "./${name}.tar.gz"
  }
}
EOF

  ok "Built ${out_dir}/${name}.wasm"
  echo "  Manifest: ${out_dir}/${name}.manifest.json"
}

main() {
  local any=false
  for rego in "${REGO_FILES[@]}"; do
    build_policy "$rego" && any=true
  done
  [[ "$any" == true ]] && ok "Done. Artifacts in: ${OUT_DIR}/" || fail "No policies compiled."
}
main "$@"
