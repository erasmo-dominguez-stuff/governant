#!/usr/bin/env bash
set -euo pipefail

# scripts/run-deploy-policy-check.sh
# Run a local deployment policy check using the Python CLI wrapper.

# Usage: ./scripts/run-deploy-policy-check.sh <input.json>
# Example: ./scripts/run-deploy-policy-check.sh test-inputs/production-valid.json

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <input.json>"
  echo "Example: $0 ../test-inputs/production-valid.json"
  exit 2
fi

INPUT="$1"

python -m opawasm.cli allow -i "$INPUT" --artifact ./.compile/github_env_protect.tar.gz --package github.deploy --strict-exit || {
  echo "Policy denied or an error occurred"
  exit 1
}

echo "Policy allowed"
