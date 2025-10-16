#!/usr/bin/env bash
set -euxo pipefail

# --- Constants ---
POLICY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.gate" && pwd)"
POLICY_FILE="$POLICY_DIR/github_env_protect.rego"
OUTPUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/.compile"
BUNDLE_FILE="$OUTPUT_DIR/github_env_protect.tar.gz"
WASM_FILE="$OUTPUT_DIR/github_env_protect.wasm"

# --- Functions ---
log() {
  echo "• $*"
}

ensure_opa() {
  if ! command -v opa &> /dev/null; then
    log "OPA not found. Installing..."
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"       # darwin | linux
    arch="$(uname -m)"
    case "$arch" in
      x86_64|amd64) arch="amd64" ;;
      arm64|aarch64) arch="arm64" ;;
      *) log "Unknown arch: $arch"; exit 1 ;;
    esac
    url="https://openpolicyagent.org/downloads/latest/opa_${os}_${arch}"
    curl -L -o opa "$url"
    chmod +x opa
    export PATH="$(pwd):$PATH"
  fi
}

build_wasm() {
  log "🧱 Building OPA WASM module..."
  mkdir -p "$OUTPUT_DIR"
  rm -f "$BUNDLE_FILE" "$WASM_FILE"

  # Create a clean temporary directory
  TMP_DIR="$(mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT

  # Copy only the policy file
  cp "$POLICY_FILE" "$TMP_DIR/"

  # Build the WASM bundle from TMP_DIR root to avoid weird absolute paths
  log "🔨 Compiling to WASM..."
  pushd "$TMP_DIR" >/dev/null
  if ! opa build \
      --target wasm \
      --optimize=0 \
      -o "$BUNDLE_FILE" \
      -e "github/deploy/allow" \
      -e "github/deploy/violations" \
      .; then
    log "❌ Error compiling to WASM"
    popd >/dev/null
    exit 1
  fi
  popd >/dev/null

  # 📦 Extracting WASM file (robust to leading slash or directory prefix)
  log "📦 Extracting WASM file..."
  wasm_entry="$(tar -tf "$BUNDLE_FILE" | grep -E '(^|/)?policy\.wasm$' | head -n1 || true)"

  if [[ -n "$wasm_entry" ]]; then
    tar -xzf "$BUNDLE_FILE" -C "$OUTPUT_DIR" "$wasm_entry"
    wasm_basename="$(basename "$wasm_entry")"
    mv "$OUTPUT_DIR/$wasm_entry" "$OUTPUT_DIR/$wasm_basename" 2>/dev/null || true
    mv "$OUTPUT_DIR/$wasm_basename" "$WASM_FILE"
    log "✅ Build successful:"
    log "   - WASM: $WASM_FILE"
  else
    log "❌ Error: policy.wasm not found in bundle"
    log "📦 Bundle contents:"
    tar -tf "$BUNDLE_FILE" || true
    exit 1
  fi
}

main() {
  ensure_opa
  build_wasm
}

main "$@"
