# Rego Policy Testing Repository

This repository contains Open Policy Agent (OPA) Rego policies for GitHub release validation, along with comprehensive testing tools and examples.

## 🎯 Overview

The repository implements a comprehensive deployment policy system that validates GitHub releases based on multiple security and compliance rules:

- **Rule #1**: Controlled, tested, and segregated deployments
- **Rule #2**: Production environment separation
- **Rule #3**: Documented changes and ticket requirements
- **Rule #4**: Agreed deployment windows and cooldown periods
- **Rule #5**: Sign-off requirements and emergency procedures
- **Rule #6**: Change control after sign-off
- **Rule #7**: Rollback instructions
- **Guardrails**: Deployment frequency limits

## 📁 Repository Structure

```
rego/
├── policies/
│   ├── github-release.rego    # Main Rego policy file
│   └── policy.json            # Policy configuration
├── test-inputs/               # Test scenarios
│   ├── production-valid.json      # Valid production deployment
│   ├── production-invalid.json    # Invalid production deployment
│   ├── staging-valid.json         # Valid staging deployment
│   └── emergency-production.json  # Emergency production deployment
├── test-policy.sh             # Basic testing script
├── test-advanced.sh           # Advanced analysis script
└── README.md                  # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Open Policy Agent (OPA)**: Install from [openpolicyproject.org](https://openpolicyproject.org/docs/latest/#running-opa)
2. **jq**: JSON processor for better output formatting

#### Installation

**macOS:**
```bash
brew install opa jq
```

**Linux:**
```bash
# Install OPA
curl -L -o opa https://openpolicyproject.org/downloads/latest/opa_linux_amd64
chmod +x opa
sudo mv opa /usr/local/bin/

# Install jq
sudo apt-get install jq
```

### Basic Testing

Run all tests:
```bash
chmod +x test-policy.sh
./test-policy.sh all
```

Run a specific test:
```bash
./test-policy.sh production-valid
```

Validate files only:
```bash
./test-policy.sh validate
```

### Advanced Analysis

Detailed analysis of a test file:
```bash
chmod +x test-advanced.sh
./test-advanced.sh analyze production-valid
```

Compare two test files:
```bash
./test-advanced.sh compare production-valid production-invalid
```

Generate coverage report:
```bash
./test-advanced.sh coverage
```

Analyze all test files:
```bash
./test-advanced.sh all
```

## 🔧 Policy Configuration

The `policies/policy.json` file contains environment-specific configurations:

- **Production**: Strict rules with full validation
- **Staging**: Moderate rules for testing
- **Development**: Relaxed rules for development

### Key Configuration Options

- `artifact_signed`: Require signed artifacts
- `min_reviewers`: Minimum number of approvers
- `allowed_branches`: Restricted branch deployment
- `windows_utc`: Deployment time windows
- `max_deployments_per_day`: Rate limiting
- `ticket_pattern`: Ticket ID validation regex

## 🧪 Test Scenarios

### Production Valid
- ✅ All rules satisfied
- ✅ Proper approvals and documentation
- ✅ Within deployment windows

### Production Invalid
- ❌ Multiple rule violations
- ❌ Insufficient approvals
- ❌ Outside deployment windows
- ❌ Missing documentation

### Staging Valid
- ✅ Environment-appropriate rules
- ✅ Basic validation passed

### Emergency Production
- ✅ Emergency path validation
- ✅ Bypasses normal restrictions
- ✅ Requires retrospective sign-off

## 📊 Understanding Results

### Test Output

```
[INFO] Running test: production-valid
[SUCCESS] ✅ production-valid: ALLOWED
---
[INFO] Running test: production-invalid
[ERROR] ❌ production-invalid: DENIED
[INFO] Violation details:
   • Rule#1: tests required but not passed
   • Rule#1: artifact must be signed
   • Rule#1: at least 2 approvers required (got 1)
```

### Advanced Analysis

```
================================
COMPLETE ANALYSIS: production-valid
================================
🎯 GENERAL RESULT: ALLOWED

[INFO] Detailed analysis by rule:

🔍 Analyzing rule1 in production-valid...
✅ rule1: NO VIOLATIONS

🔍 Analyzing rule2 in production-valid...
✅ rule2: NO VIOLATIONS

📋 VIOLATIONS SUMMARY:
   No violations found
```

## 🔍 Policy Rules Explained

### Rule #1: Controlled, Tested, Segregated
- Ensures tests are passed when required
- Validates artifact signatures
- Checks release control mechanisms
- Verifies minimum approver count
- Restricts branch deployments

### Rule #2: Production Separation
- Prevents production on shared infrastructure
- Enforces dedicated runner groups
- Maintains environment isolation

### Rule #3: Documented Changes
- Requires change records
- Validates ticket IDs against patterns
- Ensures traceability

### Rule #4: Deployment Windows
- Enforces agreed deployment dates
- Implements wait timers
- Restricts to approved time windows

### Rule #5: Sign-off & Emergency
- Requires proper sign-off
- Handles emergency procedures
- Configures retrospective requirements

### Rule #6: Change Control
- Prevents unauthorized changes after sign-off
- Maintains deployment integrity

### Rule #7: Rollback Instructions
- Ensures rollback procedures exist
- Maintains operational readiness

### Guardrails
- Limits deployment frequency
- Prevents deployment spam

## 🛠️ Customization

### Adding New Rules

1. Add rule logic to `policies/github-release.rego`
2. Update the deny aggregator
3. Add rule configuration to `policies/policy.json`
4. Create test scenarios in `test-inputs/`

### Modifying Existing Rules

1. Update rule logic in the Rego file
2. Adjust configuration parameters
3. Update test scenarios
4. Validate with test scripts

## 🐛 Troubleshooting

### Common Issues

**OPA not found:**
```bash
# Install OPA first
brew install opa  # macOS
# or
curl -L -o opa https://openpolicyproject.org/downloads/latest/opa_linux_amd64  # Linux
```

**jq not found:**
```bash
brew install jq  # macOS
sudo apt-get install jq  # Linux
```

**Policy validation errors:**
```bash
# Check Rego syntax
opa check policies/github-release.rego

# Validate JSON
jq empty policies/policy.json
```

### Debug Mode

For detailed debugging, run OPA directly:
```bash
opa eval --data policies/github-release.rego --data policies/policy.json --input test-inputs/production-valid.json "data.policy.github.release"
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## 📝 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

For issues and questions:
1. Check the troubleshooting section
2. Review OPA documentation
3. Open an issue in the repository

## 🔗 Resources

- [Open Policy Agent Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [OPA Playground](https://play.openpolicyagent.org/)
- [GitHub Actions Integration](https://www.openpolicyagent.org/docs/latest/integrations/github/)
