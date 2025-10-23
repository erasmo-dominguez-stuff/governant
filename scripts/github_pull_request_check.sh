#!/usr/bin/env bash
set -euo pipefail


# scripts/github-pull-request-check.sh
# Evaluate the pull request policy for a given input document using the Python CLI.
#
# Usage: ./scripts/github-pull-request-check.sh <input.json>
# Example: ./scripts/github-pull-request-check.sh test-inputs/pr_valid.json

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <input.json>"
  exit 2
fi

INPUT_FILE="$1"

python -m opawasm.cli allow -i "$INPUT_FILE" --artifact ./.compile/github_env_protect.tar.gz --package github.pull_request --strict-exit
