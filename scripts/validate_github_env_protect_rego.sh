#!/bin/bash
# Validate github_env_protect_policy.json against Rego policy using OPA

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if OPA is installed
if ! command -v opa &> /dev/null; then
    echo -e "${RED}Error: OPA (Open Policy Agent) is required but not installed.${NC}"
    echo "Install it from: https://www.openpolicyagent.org/docs/latest/#running-opa"
    exit 1
fi

# Set default file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(dirname "$SCRIPT_DIR")/.governant"
POLICY_FILE="$GATE_DIR/policies/github_env_protect_policy.json"
REGO_FILE="$GATE_DIR/code/github_env_protect.rego"

# Check if files exist
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}Error: github_env_protect_policy.json not found at $POLICY_FILE${NC}"
    exit 1
fi

if [ ! -f "$REGO_FILE" ]; then
    echo -e "${RED}Error: Rego file not found at $REGO_FILE${NC}"
    exit 1
fi

echo -e "🔍 Validating $POLICY_FILE with $(basename "$REGO_FILE")..."

# Create a temporary file for the input
TEMP_INPUT=$(mktemp)
trap 'rm -f "$TEMP_INPUT"' EXIT

# Create input document with policy data as input
jq -n --argjson input "$(cat "$POLICY_FILE")" '{input: $input}' > "$TEMP_INPUT"

# Run OPA eval
if opa eval --format pretty \
    --data "$REGO_FILE" \
    --input "$TEMP_INPUT" \
    'data' > /dev/null 2>&1; then
    
    # If basic validation passes, check for any deny rules
    RESULT=$(opa eval --format raw \
        --data "$REGO_FILE" \
        --input "$TEMP_INPUT" \
        'data' 2>/dev/null | jq -r '.')
    
    # Check if there are any deny rules that evaluate to true
    DENY_RESULT=$(echo "$RESULT" | jq -r '.. | .deny? | select(. == true)' 2>/dev/null || true)
    
    if [ "$DENY_RESULT" = "true" ]; then
        echo -e "${RED}❌ Policy validation failed: Access denied${NC}"
        echo -e "\nEvaluation result:"
        echo "$RESULT" | jq .
        exit 1
    else
        echo -e "${GREEN}✅ Policy is valid according to the Rego rules!${NC}"
        exit 0
    fi
else
    echo -e "${RED}❌ Policy validation failed: Invalid Rego policy${NC}"
    echo -e "\nChecking Rego syntax..."
    opa check "$REGO_FILE"
    exit 1
fi
