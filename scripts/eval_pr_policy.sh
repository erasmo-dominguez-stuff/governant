#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <input.json>"
  exit 2
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
  echo "Input file not found: $INPUT"
  exit 2
fi

echo "Evaluating PR policy for input: $INPUT"
echo
echo "-- input summary --"
jq '{environment: .environment, ref: .ref, approvers: .workflow_meta.approvers, signed_off: .workflow_meta.signed_off}' "$INPUT" || true
echo
echo "-- opa evaluation: allow --"
allow_json=$(opa eval --format json --data .governant/code --input "$INPUT" 'data.github.pullrequest.allow')
allow=$(echo "$allow_json" | jq -r '.result[0].expressions[0].value // false') || true
echo "allow: $allow"
echo
echo "-- opa evaluation: violations --"
violations_json=$(opa eval --format json --data .governant/code --input "$INPUT" 'data.github.pullrequest.violations')
vio=$(echo "$violations_json" | jq -c '[.result[0].expressions[0].value[]?] // []') || true
echo "violations: $vio"

exit 0
