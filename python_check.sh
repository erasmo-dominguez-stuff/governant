#!/bin/bash
set -e  # Exit on error

# Install runtime if not already installed
echo "🔧 Installing opa-wasm runtime..."
python -m pip install --upgrade pip
python -m pip install 'opa-wasm[cranelift]' --no-cache-dir

# Install the package in development mode
echo "📦 Installing package in development mode..."
pip install -e .

# Set default paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALID_INPUT="$SCRIPT_DIR/test-inputs/production-valid.json"
INVALID_INPUT="$SCRIPT_DIR/test-inputs/production-invalid.json"
WASM_BUNDLE="$SCRIPT_DIR/.compile/github_env_protect.tar.gz"

# Check if input files exist
for file in "$VALID_INPUT" "$INVALID_INPUT"; do
    if [ ! -f "$file" ]; then
        echo "❌ Error: Input file not found: $file"
        exit 1
    fi
done

# Check if WASM bundle exists
if [ ! -f "$WASM_BUNDLE" ]; then
    echo "❌ Error: WASM bundle not found at $WASM_BUNDLE"
    echo "Please run the compile-policy workflow first"
    echo "Looking for bundle in:"
    find "$SCRIPT_DIR" -name "*.tar.gz" -o -name "*.wasm"
    exit 1
fi

# Function to run command with error handling
run_command() {
    local cmd=("$@")
    echo -e "\n🚀 Running: ${cmd[*]}"
    PYTHONPATH="$SCRIPT_DIR" python -c "import sys; print(sys.path)" > /dev/null  # Warm up Python
    if ! output=$(PYTHONPATH="$SCRIPT_DIR" "${cmd[@]}" 2>&1); then
        echo -e "❌ Error:\n$output"
        return 1
    else
        echo -e "✅ Output:\n$output"
        return 0
    fi
}

# 1. Evaluate allow (true/false)
run_command python -m src.opawasm.cli --artifact "$WASM_BUNDLE" allow -i "$VALID_INPUT" --output bool

# 2. List violations
run_command python -m src.opawasm.cli --artifact "$WASM_BUNDLE" violations -i "$INVALID_INPUT"

# 3. Evaluate arbitrary entrypoint
run_command python -m src.opawasm.cli --artifact "$WASM_BUNDLE" eval -i "$VALID_INPUT" -e "data.github.deploy.allow"

echo -e "\n🎉 All commands completed!"