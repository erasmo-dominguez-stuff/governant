# GitHub Gate - Simplified Deployment Policy Engine

A simplified, lightweight deployment policy engine for GitHub releases using Open Policy Agent (OPA) and Rego policies.

## Overview

This project provides a streamlined approach to enforcing deployment policies across different environments (production, staging, development) with minimal configuration and maximum clarity.

## Features

- **Simplified Policy Configuration**: Minimal JSON configuration with only essential rules
- **Environment-Specific Rules**: Different validation rules for production, staging, and development
- **OPA Integration**: Uses Open Policy Agent for policy evaluation
- **Python Validation**: Python scripts for testing and validation
- **GitHub Actions**: Automated CI/CD workflows for policy validation

## Policy Rules

The simplified policy enforces 6 core rules:

1. **Approval Requirements**: Minimum number of approvers required
2. **Branch Authorization**: Only specific branches allowed per environment
3. **Ticket Requirements**: Valid ticket IDs when required
4. **Test Requirements**: Tests must pass when required
5. **Sign-off Requirements**: Required sign-offs for deployment
6. **Rate Limiting**: Daily deployment limits per environment

## Configuration

### Policy Structure (`policies/policy.json`)

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

### Running Tests

```bash
# Run all validation tests
python scripts/validate_policy.py

# Run comprehensive test scenarios
python scripts/test_all_scenarios.py

# Run performance benchmarks
python scripts/benchmark_policy.py
```

### Using OPA Directly

```bash
# Validate Rego syntax
opa check policies/github-release.rego

# Test with input file
opa eval --data policies/policy.json --input test-inputs/production-valid.json 'data.policy.github.release.allow'
```

### GitHub Actions

The project includes automated workflows:

- **Python WASM Validation**: Builds WASM bundles and runs Python validation
- **Test Policies**: Comprehensive policy testing with OPA

## File Structure

```
├── policies/
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

## Simplification Changes

This version has been significantly simplified:

- ✅ Removed all references to "techlink"
- ✅ Reduced policy parameters from 20+ to 7 essential rules
- ✅ Simplified Rego code from 343 lines to 67 lines
- ✅ Streamlined test inputs to only essential fields
- ✅ Updated validation scripts to match simplified policy
- ✅ Maintained core security and compliance requirements

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests to ensure everything works
5. Submit a pull request

## License

MIT License - see LICENSE file for details.