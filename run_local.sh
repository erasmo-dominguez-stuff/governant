#!/bin/bash

# Ensure the script is run from the project root
if [ ! -f "pyproject.toml" ]; then
    echo "Please run this script from the project root directory."
    exit 1
fi

# Install dependencies and run the CLI using uv
# This ensures a consistent environment for execution

# Create a virtual environment and install dependencies
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    uv venv
fi

# Activate the virtual environment for this script
source .venv/bin/activate

# Install project (editable) and Python SDK (opa-wasm)
uv pip install -e .
uv pip install "opa-wasm[cranelift]"

# Ensure src/ is importable when running module
export PYTHONPATH="$(pwd)/src:${PYTHONPATH}"

# Compile policy to produce a fresh .compile/<name>.wasm
./scripts/compile_policy.sh

# Run the policy evaluation using the new CLI (prefer OPA CLI for robustness)
python -m opawasm \
    .compile/github-release.tar.gz \
    test-inputs/production-valid.json \
    --prefer opa \
    --entrypoint data.github.deploy.allow \
    --format pretty
