#!/bin/bash

# Advanced script for detailed Rego policy analysis
# Author: DevOps Toolchain
# Date: 2025-01-18

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Función para imprimir con colores
print_header() {
    echo -e "${PURPLE}================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}================================${NC}"
}

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

print_detail() {
    echo -e "${CYAN}$1${NC}"
}

# Function for detailed analysis of a specific rule
analyze_rule() {
    local test_file=$1
    local rule_name=$2
    local test_name=$(basename "$test_file" .json)
    
    print_detail "🔍 Analyzing $rule_name in $test_name..."
    
    # Get specific violations for the rule
    local violations
    violations=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$test_file" "data.policy.github.release.${rule_name}_violations" 2>/dev/null | jq -r '.result[0].expressions[0].value | to_entries[] | .key' 2>/dev/null || echo "")
    
    if [[ -n "$violations" ]]; then
        print_error "❌ $rule_name: VIOLATIONS FOUND"
        echo "$violations" | while IFS= read -r violation; do
            if [[ -n "$violation" ]]; then
                echo "   • $violation"
            fi
        done
    else
        print_success "✅ $rule_name: NO VIOLATIONS"
    fi
}

# Function for complete analysis of a test file
analyze_test_file() {
    local test_file=$1
    local test_name=$(basename "$test_file" .json)
    
    print_header "COMPLETE ANALYSIS: $test_name"
    
    # General result
    local result
    result=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$test_file" "data.policy.github.release.allow")
    local allowed
    allowed=$(echo "$result" | jq -r '.result[0].expressions[0].value')
    
    if [[ "$allowed" == "true" ]]; then
        print_success "🎯 GENERAL RESULT: ALLOWED"
    else
        print_error "🚫 GENERAL RESULT: DENIED"
    fi
    
    echo ""
    
    # Analysis by rule
    print_status "Detailed analysis by rule:"
    echo ""
    
    analyze_rule "$test_file" "controlled_tested_segregated"
    analyze_rule "$test_file" "production_separation"
    analyze_rule "$test_file" "documented_changes"
    analyze_rule "$test_file" "deployment_windows"
    analyze_rule "$test_file" "approvals_signoff"
    analyze_rule "$test_file" "change_control"
    analyze_rule "$test_file" "rollback_procedures"
    analyze_rule "$test_file" "rate_limiting"
    
    echo ""
    
    # Show all violations
    print_status "📋 VIOLATIONS SUMMARY:"
    local all_violations
    all_violations=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$test_file" "data.policy.github.release.deny" 2>/dev/null | jq -r '.result[0].expressions[0].value | to_entries[] | .key' 2>/dev/null || echo "")
    
    if [[ -n "$all_violations" ]]; then
        echo "$all_violations" | while IFS= read -r violation; do
            if [[ -n "$violation" ]]; then
                echo "   • $violation"
            fi
        done
    else
        print_success "   No violations found"
    fi
    
    echo ""
    echo "---"
}

# Function to compare two test files
compare_tests() {
    local file1=$1
    local file2=$2
    
    if [[ ! -f "$file1" ]] || [[ ! -f "$file2" ]]; then
        print_error "One or both files do not exist"
        return 1
    fi
    
    local name1=$(basename "$file1" .json)
    local name2=$(basename "$file2" .json)
    
    print_header "COMPARISON: $name1 vs $name2"
    
    # Results
    local result1
    local result2
    result1=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$file1" "data.policy.github.release.allow")
    result2=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$file2" "data.policy.github.release.allow")
    
    local allowed1
    local allowed2
    allowed1=$(echo "$result1" | jq -r '.result[0].expressions[0].value')
    allowed2=$(echo "$result2" | jq -r '.result[0].expressions[0].value')
    
    echo "📊 RESULTS:"
    echo "   $name1: $allowed1"
    echo "   $name2: $allowed2"
    echo ""
    
    # Violations
    local violations1
    local violations2
    violations1=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$file1" "data.policy.github.release.deny" 2>/dev/null | jq -r '.result[0].expressions[0].value[]?' 2>/dev/null || echo "")
    violations2=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$file2" "data.policy.github.release.deny" 2>/dev/null | jq -r '.result[0].expressions[0].value' 2>/dev/null || echo "")
    
    local count1=$(echo "$violations1" | grep -c . || echo "0")
    local count2=$(echo "$violations2" | grep -c . || echo "0")
    
    echo "📈 VIOLATIONS:"
    echo "   $name1: $count1 violations"
    echo "   $name2: $count2 violations"
    
    if [[ "$count1" -lt "$count2" ]]; then
        print_success "   $name1 has fewer violations"
    elif [[ "$count1" -gt "$count2" ]]; then
        print_warning "   $name2 has fewer violations"
    else
        print_status "   Both have the same number of violations"
    fi
    
    echo ""
}

# Function to generate coverage report
generate_coverage_report() {
    print_header "RULE COVERAGE REPORT"
    
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    echo "📊 STATISTICS BY RULE:"
    echo ""
    
    # Count violations by rule
    for test_file in test-inputs/*.json; do
        if [[ -f "$test_file" ]]; then
            total_tests=$((total_tests + 1))
            
            local result
            result=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$test_file" "data.policy.github.release.allow")
            local allowed
            allowed=$(echo "$result" | jq -r '.result[0].expressions[0].value')
            
            if [[ "$allowed" == "true" ]]; then
                passed_tests=$((passed_tests + 1))
            else
                failed_tests=$((failed_tests + 1))
            fi
        fi
    done
    
    echo "   Total tests: $total_tests"
    echo "   Successful tests: $passed_tests"
    echo "   Failed tests: $failed_tests"
    echo "   Success rate: $((passed_tests * 100 / total_tests))%"
    echo ""
    
    # Analysis by rule
    local rules=("controlled_tested_segregated" "production_separation" "documented_changes" "deployment_windows" "approvals_signoff" "change_control" "rollback_procedures" "rate_limiting")
    
    for rule in "${rules[@]}"; do
        local rule_violations=0
        
        for test_file in test-inputs/*.json; do
            if [[ -f "$test_file" ]]; then
                local violations
                violations=$(opa eval --data policies/github-release.rego --data policies/policy.json --input "$test_file" "data.policy.github.release.${rule}_violations" 2>/dev/null | jq -r '.result[0].expressions[0].value[]?' 2>/dev/null || echo "")
                
                if [[ -n "$violations" ]]; then
                    local count=$(echo "$violations" | grep -c . || echo "0")
                    rule_violations=$((rule_violations + count))
                fi
            fi
        done
        
        echo "   $rule: $rule_violations total violations"
    done
    
    echo ""
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTION] [ARGUMENTS]"
    echo ""
    echo "Options:"
    echo "  analyze <test-file>     Complete analysis of a test file"
    echo "  compare <file1> <file2> Compare two test files"
    echo "  coverage                Generate coverage report"
    echo "  all                     Analyze all test files"
    echo "  help                    Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 analyze production-valid     # Complete analysis of production-valid"
    echo "  $0 compare production-valid production-invalid"
    echo "  $0 coverage                      # Coverage report"
    echo "  $0 all                          # Analyze all files"
    echo ""
    echo "Available test files:"
    ls -1 test-inputs/*.json | sed 's|test-inputs/||' | sed 's|.json||' | sed 's/^/  /'
}

# Main function
main() {
    print_status "🔬 Starting advanced Rego policy analysis"
    echo ""
    
    # Check dependencies
    if ! command -v opa &> /dev/null; then
        print_error "Open Policy Agent (OPA) is not installed."
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed. Install it for better output formatting."
        exit 1
    fi
    
    # Process arguments
    case "${1:-help}" in
        "analyze")
            if [[ -z "$2" ]]; then
                print_error "Must specify a test file"
                show_help
                exit 1
            fi
            local test_file="test-inputs/${2}.json"
            if [[ ! -f "$test_file" ]]; then
                print_error "Test file not found: $test_file"
                exit 1
            fi
            analyze_test_file "$test_file"
            ;;
        "compare")
            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                print_error "Must specify two test files"
                show_help
                exit 1
            fi
            local file1="test-inputs/${2}.json"
            local file2="test-inputs/${3}.json"
            compare_tests "$file1" "$file2"
            ;;
        "coverage")
            generate_coverage_report
            ;;
        "all")
            for test_file in test-inputs/*.json; do
                if [[ -f "$test_file" ]]; then
                    analyze_test_file "$test_file"
                fi
            done
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    
    print_status "🏁 Analysis completed"
}

# Execute main function
main "$@"
