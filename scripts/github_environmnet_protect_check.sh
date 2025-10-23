#!/usr/bin/env bash
set -euo pipefail

# scripts/github-environment-protect-check.sh
# Evaluate the environment protection policy for a given input document.
# This will run the Python CLI wrapper against the compiled bundle.
#
# Usage: ./scripts/github-environment-protect-check.sh <input.json>
# Example: ./scripts/github-environment-protect-check.sh test-inputs/production-valid.json

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <input.json>"
  exit 2
fi

INPUT_FILE="$1"

python -m opawasm.cli allow -i "$INPUT_FILE" --artifact ./.compile/github_env_protect.tar.gz --package github.deploy --strict-exit
