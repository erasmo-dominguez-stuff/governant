TODO 

fix python cli execution. Its seems related to module configuration

fix opa-evaluation.yml , uv its not working 


# GitHub Gate - Deployment Policy Engine

A comprehensive deployment policy engine for GitHub releases using Open Policy Agent (OPA) and Rego policies with JSON Schema validation.

## Overview

This project implements a three-layer architecture for deployment policy enforcement:

1. **`.gate/policy.json`** - Team configuration (what they want to enforce)
2. **`.gate/schema.json`** - Structure validation (JSON Schema for policy.json)
3. **`.gate/*.rego`** - Policy logic (OPA Rego rules that decide allow/deny)

## Architecture

### Layer 1: Policy Configuration (`.gate/policy.json`)
**What it is**: A configuration file that each team stores in their repository.
**Purpose**: Declare their rules (e.g., allowed branches, number of approvals, ticket patterns, etc.).
**Mental model**: This contains NO "validation code". Only data that says: "this is how we play in this repo."

### Layer 2: Schema Validation (`.gate/schema.json`)
**What it is**: A JSON Schema that defines the structure and types of policy.json.
**Purpose**: Catch simple errors before reaching logic: misspelled fields, incorrect types, etc.
**Mental model**: The schema only answers: "is it well-formed?". It doesn't decide if you can deploy.

### Layer 3: Policy Logic (`.gate/*.rego`)
**What it is**: Rego code (OPA) that implements the semantics: "given team rules + deployment context, allow or block?".
**Purpose**: Make the compliance decision by reading:
- The policy.json (already validated by schema)
- The context (branch, environment, number of deployments today, tickets, passed checks, etc.)

## Features

- **Three-Layer Architecture**: Schema validation, policy configuration, and logic separation
- **Environment-Specific Rules**: Different validation rules for production, staging, and development
- **OPA Integration**: Uses Open Policy Agent for policy evaluation with structured violations
- **JSON Schema Validation**: Automatic validation of policy structure before execution
- **Python Validation**: Python scripts for testing and validation
- **Structured Violations**: Detailed violation reporting with error codes and messages

## Policy Rules

The simplified policy enforces 6 core rules:

1. **Approval Requirements**: Minimum number of approvers required
2. **Branch Authorization**: Only specific branches allowed per environment
3. **Ticket Requirements**: Valid ticket IDs when required
4. **Test Requirements**: Tests must pass when required
5. **Sign-off Requirements**: Required sign-offs for deployment
6. **Rate Limiting**: Daily deployment limits per environment

## Configuration

### Policy Structure (`.gate/policy.json`)

```json
{
  "policy": {
    "version": "1.0.0",
    "metadata": {
      "description": "Simplified deployment policy",
      "last_updated": "2025-01-18"
    },
    "environments": {
      "production": {
        "enabled": true,
        "rules": {
          "approvals_required": 2,
          "allowed_branches": ["main"],
          "require_ticket": true,
          "ticket_pattern": "^(INC|CHG|REQ)-[0-9]{6,}$",
          "tests_passed": true,
          "signed_off": true,
          "max_deployments_per_day": 5
        }
      },
      "staging": {
        "enabled": true,
        "rules": {
          "approvals_required": 1,
          "allowed_branches": ["main", "develop"],
          "require_ticket": false,
          "tests_passed": true,
          "signed_off": false,
          "max_deployments_per_day": 20
        }
      },
      "development": {
        "enabled": true,
        "rules": {
          "approvals_required": 0,
          "allowed_branches": null,
          "require_ticket": false,
          "tests_passed": false,
          "signed_off": false,
          "max_deployments_per_day": 50
        }
      }
    }
  }
}
```

## Usage

### Schema Validation

```bash
# Validate policy.json against schema.json
python scripts/validate_schema.py

# Using jsonschema directly (if installed)
jsonschema -i .gate/policy.json .gate/schema.json
```

### Policy Execution

```bash
# Execute policy with structured input
python scripts/execute_policy.py

# Using OPA directly
opa eval --data .gate/github-release.rego --input input.json data.github.deploy.allow
opa eval --data .gate/github-release.rego --input input.json data.github.deploy.violations
```

### Running Tests

```bash
# Run all validation tests
python scripts/validate_policy.py

# Run comprehensive test scenarios
python scripts/test_all_scenarios.py

# Run performance benchmarks
python scripts/benchmark_policy.py

# Run OPA tests
./test-policy.sh all
```

### Using OPA Directly

```bash
# Validate Rego syntax
opa check .gate/github-release.rego

# Test with input file
opa eval --data .gate/github-release.rego --input test-inputs/production-valid.json data.github.deploy.allow
```

### GitHub Actions

The project includes automated workflows:

- **Python WASM Validation**: Builds WASM bundles and runs Python validation
- **Test Policies**: Comprehensive policy testing with OPA

## File Structure

```
├── .gate/
│   ├── github-release.rego    # Simplified Rego policy
│   └── policy.json            # Simplified configuration
├── scripts/
│   ├── validate_policy.py     # Main validation script
│   ├── test_all_scenarios.py  # Comprehensive testing
│   └── benchmark_policy.py    # Performance benchmarking
├── test-inputs/               # Test scenarios
├── .github/workflows/         # GitHub Actions workflows
└── README.md
```

## Test Scenarios

The `test-inputs/` directory contains simplified test cases:

- `production-valid.json`: Valid production deployment
- `production-invalid.json`: Invalid production deployment
- `staging-valid.json`: Valid staging deployment
- `emergency-production.json`: Emergency production scenario

## Requirements

- Python 3.11+
- Open Policy Agent (OPA)
- wasmtime (for WASM support)

## Installation

```bash
# Install Python dependencies
pip install -r requirements.txt

# Install OPA
curl -L -o opa https://openpolicyproject.org/downloads/latest/opa_linux_amd64
chmod +x opa
sudo mv opa /usr/local/bin/
```

## Implementation Details

This version implements the three-layer architecture:

- ✅ **Schema Layer**: JSON Schema validation for policy structure
- ✅ **Configuration Layer**: Team-specific policy configuration in `.gate/policy.json`
- ✅ **Logic Layer**: OPA Rego rules with structured violation reporting
- ✅ **Structured Input**: Complete deployment context with environment, refs, tickets, approvals
- ✅ **Error Codes**: Detailed violation reporting with specific error codes and messages
- ✅ **Validation Scripts**: Separate scripts for schema validation and policy execution
- ✅ **Test Coverage**: Comprehensive test inputs with new structured format

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests to ensure everything works
5. Submit a pull request

## License

MIT License - see LICENSE file for details.