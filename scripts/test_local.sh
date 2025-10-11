#!/bin/bash

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🚀 Starting local test suite...${NC}\n"

# Function to run OPA tests
run_opa_tests() {
    echo -e "${YELLOW}🔍 Running OPA tests...${NC}"
    
    # Check if OPA is installed
    if ! command -v opa &> /dev/null; then
        echo "OPA not found. Installing OPA..."
        curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
        chmod +x opa
        sudo mv opa /usr/local/bin/
    fi
    
    # Validate Rego syntax
    echo -e "\n${YELLOW}✅ Validating Rego syntax...${NC}"
    if [ -d ".gate" ]; then
        opa check .gate/*.rego
        echo -e "${GREEN}✓ Rego syntax is valid${NC}"
    else
        echo -e "${YELLOW}⚠️ .gate directory not found, skipping Rego validation${NC}"
    fi
    
    # Run OPA tests if they exist
    if [ -f "test-policy.sh" ]; then
        echo -e "\n${YELLOW}🏃 Running policy tests...${NC}"
        chmod +x test-policy.sh
        ./test-policy.sh all
    fi
}

# Function to run Python tests
run_python_tests() {
    echo -e "\n${YELLOW}🐍 Running Python tests...${NC}"
    
    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        echo "Python 3 is required but not installed. Please install Python 3.8 or higher."
        exit 1
    fi
    
    # Install Python dependencies
    echo -e "\n${YELLOW}📦 Installing Python dependencies...${NC}"
    python3 -m pip install --upgrade pip
    python3 -m pip install -e .[dev]
    
    # Run pytest with coverage
    echo -e "\n${YELLOW}🧪 Running tests with pytest...${NC}"
    python3 -m pytest -v --cov=src --cov-report=term-missing
    
    # Run type checking
    echo -e "\n${YELLOW}🔍 Running type checking...${NC}"
    python3 -m mypy src/
    
    # Run linting
    echo -e "\n${YELLOW}✨ Running linters...${NC}"
    python3 -m black --check src/ tests/
    python3 -m isort --check-only src/ tests/
    python3 -m flake8 src/ tests/
}

# Function to run end-to-end tests
run_e2e_tests() {
    echo -e "\n${YELLOW}🔗 Running end-to-end tests...${NC}"
    
    if [ -d "test-inputs" ]; then
        for test_file in test-inputs/*.json; do
            if [ -f "$test_file" ]; then
                echo -e "\n${YELLOW}🧪 Testing with ${test_file}...${NC}"
                
                # Check if OPA policy exists
                if [ -f ".gate/github-release.rego" ]; then
                    echo "Testing with OPA:"
                    opa eval --data .gate/github-release.rego --input "$test_file" "data.policy.github.release.allow" || true
                    echo ""
                fi
                
                # Check if Python validator exists
                if [ -f "src/validate.py" ]; then
                    echo "Testing with Python validator:"
                    python3 -m src.validate --input "$test_file" || true
                fi
            fi
        done
    else
        echo -e "${YELLOW}⚠️ test-inputs directory not found, skipping end-to-end tests${NC}"
    fi
}

# Main execution
main() {
    run_opa_tests
    run_python_tests
    run_e2e_tests
    
    echo -e "\n${GREEN}✨ All tests completed successfully!${NC}"
}

main "$@"
