#!/bin/bash

# Script to test Rego policies with Open Policy Agent
# Author: DevOps Toolchain
# Date: 2025-01-18

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if OPA is installed
check_opa() {
    if ! command -v opa &> /dev/null; then
        print_error "Open Policy Agent (OPA) is not installed."
        print_status "Installing OPA..."
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            brew install opa
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            curl -L -o opa https://openpolicyproject.org/downloads/latest/opa_linux_amd64
            chmod +x opa
            sudo mv opa /usr/local/bin/
        else
            print_error "Unsupported operating system. Install OPA manually from: https://openpolicyproject.org/docs/latest/#running-opa"
            exit 1
        fi
    fi
    
    OPA_VERSION=$(opa version)
    print_success "OPA installed: $OPA_VERSION"
}

# Function to run a test
run_test() {
    local test_file=$1
    local test_name=$(basename "$test_file" .json)
    
    print_status "Running test: $test_name"
    
    # Execute OPA eval
    local result
    result=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$test_file" "data.policy.github.release.allow")
    
    # Extract the result
    local allowed
    allowed=$(echo "$result" | jq -r '.result[0].expressions[0].value')
    
    if [[ "$allowed" == "true" ]]; then
        print_success "✅ $test_name: ALLOWED"
    else
        print_error "❌ $test_name: DENIED"
        
        # Show violations
        print_status "Violation details:"
        opa eval --data policies/github-release.rego --data policies/policy.json --input "$test_file" "data.policy.github.release.deny" | jq -r '.result[0].expressions[0].value[]?' 2>/dev/null || echo "Could not get details"
    fi
    
    echo "---"
}

# Function to run all tests
run_all_tests() {
    print_status "Running all tests..."
    echo ""
    
    for test_file in test-inputs/*.json; do
        if [[ -f "$test_file" ]]; then
            run_test "$test_file"
        fi
    done
}

# Function to run a specific test
run_specific_test() {
    local test_name=$1
    local test_file="test-inputs/${test_name}.json"
    
    if [[ ! -f "$test_file" ]]; then
        print_error "Test file not found: $test_file"
        print_status "Available tests:"
        ls -1 test-inputs/*.json | sed 's|test-inputs/||' | sed 's|.json||'
        exit 1
    fi
    
    run_test "$test_file"
}

# Function to validate Rego syntax
validate_rego() {
    print_status "Validating Rego syntax..."
    
    if opa check policies/github-release.rego; then
        print_success "✅ Valid Rego syntax"
    else
        print_error "❌ Syntax errors in Rego"
        exit 1
    fi
}

# Function to validate JSON
validate_json() {
    print_status "Validating JSON files..."
    
    local json_files=("policies/policy.json" "test-inputs/"*.json)
    
    for file in "${json_files[@]}"; do
        if [[ -f "$file" ]]; then
            if jq empty "$file" 2>/dev/null; then
                print_success "✅ $file: Valid JSON"
            else
                print_error "❌ $file: Invalid JSON"
                exit 1
            fi
        fi
    done
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  all                    Run all tests"
    echo "  <test-name>            Run a specific test (without .json)"
    echo "  validate               Only validate syntax and JSON"
    echo "  help                   Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 all                           # Run all tests"
    echo "  $0 production-valid              # Run only production-valid"
    echo "  $0 validate                      # Only validate files"
    echo ""
    echo "Available tests:"
    ls -1 test-inputs/*.json | sed 's|test-inputs/||' | sed 's|.json||' | sed 's/^/  /'
}

# Main function
main() {
    print_status "🚀 Starting Rego policy tests"
    echo ""
    
    # Check dependencies
    check_opa
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Install it for better output formatting."
        print_status "macOS: brew install jq"
        print_status "Linux: sudo apt-get install jq"
    fi
    
    # Validate files
    validate_rego
    validate_json
    echo ""
    
    # Process arguments
    case "${1:-all}" in
        "all")
            run_all_tests
            ;;
        "validate")
            print_success "✅ Validation completed"
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            run_specific_test "$1"
            ;;
    esac
    
    print_status "🏁 Tests completed"
}

# Ejecutar función principal
main "$@"
