#!/bin/bash

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if OPA is installed
check_opa_installed() {
    if ! command -v opa &> /dev/null; then
        echo -e "${YELLOW}OPA not found. Installing OPA...${NC}"
        curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
        chmod +x opa
        export PATH="$PWD:$PATH"
    fi
    
    echo -e "${GREEN}✓ OPA version:${NC} $(opa version)"
}

# Validate Rego syntax
validate_rego() {
    echo -e "\n${YELLOW}🔍 Validating Rego syntax...${NC}"
    if [ -d ".gate" ]; then
        if ls .gate/*.rego 1> /dev/null 2>&1; then
            opa check .gate/*.rego
            echo -e "${GREEN}✓ Rego syntax is valid${NC}"
        else
            echo -e "${YELLOW}⚠️ No .rego files found in .gate directory${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️ .gate directory not found, skipping Rego validation${NC}"
    fi
}

# Run OPA tests
run_opa_tests() {
    echo -e "\n${YELLOW}🧪 Running OPA tests...${NC}"
    
    if [ -f "test-policy.sh" ]; then
        chmod +x test-policy.sh
        ./test-policy.sh all
    else
        echo -e "${YELLOW}⚠️ test-policy.sh not found, skipping OPA tests${NC}"
    fi
}

# Test policy evaluation
test_policy_evaluation() {
    echo -e "\n${YELLOW}🧠 Testing policy evaluation...${NC}"
    
    if [ ! -d "test-inputs" ]; then
        echo -e "${YELLOW}⚠️ test-inputs directory not found, creating example...${NC}"
        mkdir -p test-inputs
        cat > test-inputs/example.json <<EOL
{
    "env": "production",
    "ref_type": "branch",
    "ref": "refs/heads/main",
    "artifact_signed": true,
    "release_controlled": true,
    "approvers": ["user1", "user2"],
    "tests_passed": true,
    "ticket_id": "CHG-123456"
}
EOL
    fi
    
    if [ -f ".gate/github-release.rego" ]; then
        for test_file in test-inputs/*.json; do
            if [ -f "$test_file" ]; then
                echo -e "\n${YELLOW}📄 Testing with ${test_file}:${NC}"
                echo "Input:"
                cat "$test_file"
                echo -e "\nResult:"
                opa eval --format pretty --data .gate/github-release.rego --input "$test_file" "data.policy.github.release"
            fi
        done
    else
        echo -e "${YELLOW}⚠️ .gate/github-release.rego not found, skipping policy evaluation${NC}"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}🚀 Starting OPA test suite...${NC}"
    
    check_opa_installed
    validate_rego
    run_opa_tests
    test_policy_evaluation
    
    echo -e "\n${GREEN}✨ OPA test suite completed successfully!${NC}"
}

main "$@"
