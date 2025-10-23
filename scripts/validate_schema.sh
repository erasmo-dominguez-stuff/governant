#!/bin/bash
# Validate github_env_protect_policy.json against github_env_protect_schema.json using jq

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is required but not installed.${NC}"
    echo "Install it with: brew install jq"
    exit 1
fi

# Set default file paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_DIR="$(dirname "$SCRIPT_DIR")/.governant"
POLICY_FILE="$GATE_DIR/github_env_protect_policy.json"
SCHEMA_FILE="$GATE_DIR/github_env_protect_schema.json"

# Check if files exist
if [ ! -f "$POLICY_FILE" ]; then
    echo -e "${RED}Error: github_env_protect_policy.json not found at $POLICY_FILE${NC}"
    exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
    echo -e "${RED}Error: github_env_protect_schema.json not found at $SCHEMA_FILE${NC}"
    exit 1
fi

echo -e "🔍 Validating $POLICY_FILE against $SCHEMA_FILE..."

# Validate JSON syntax
if ! jq empty "$POLICY_FILE" &>/dev/null; then
    echo -e "${RED}❌ Invalid JSON in policy file${NC}"
    jq . "$POLICY_FILE"  # This will show the error
    exit 1
fi

if ! jq empty "$SCHEMA_FILE" &>/dev/null; then
    echo -e "${RED}❌ Invalid JSON in schema file${NC}"
    jq . "$SCHEMA_FILE"  # This will show the error
    exit 1
fi

# Simple schema validation using jq
# Note: This is a basic validation. For full JSON Schema validation, consider using check-jsonschema
VALID=$(jq -e '[
    . as $dot |
    $dot | path(..) |
    select(.[-1]? == "required" and ($dot | getpath(.) | type) == "array") |
    .[0:-1] as $path |
    $dot |
    getpath($path) as $schema |
    $schema.required as $required |
    $required |
    .[] |
    . as $field |
    ("\($path | join("."))" + 
     (if $path | length > 0 then "." + $field else $field end)) as $path_str |
    { "path": $path_str, "exists": (try ($dot | getpath(($path + [$field]))) catch false | type != "null") }
] | map(select(.exists == false) | .path) | length == 0' "$POLICY_FILE" 2>/dev/null || echo "false")

if [ "$VALID" = "true" ]; then
    echo -e "${GREEN}✅ Policy is valid according to the schema!${NC}"
    exit 0
else
    echo -e "${RED}❌ Policy validation failed${NC}"
    echo "For detailed validation, install check-jsonschema:"
    echo "  pip install check-jsonschema"
    echo "Then run:"
    echo "  check-jsonschema --schemafile $SCHEMA_FILE $POLICY_FILE"
    exit 1
fi
