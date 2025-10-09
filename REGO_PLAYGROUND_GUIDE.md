# Rego Playground Guide

This guide explains how to use the [Rego Playground](https://play.openpolicyagent.org/) to test and validate the GitHub Release policies.

## 🎯 What is Rego Playground?

The Rego Playground is an online tool that allows you to:
- Write and test Rego policies
- Validate policy syntax
- Test policies with sample inputs
- See real-time results
- Share policies with others

## 🚀 Getting Started

### 1. Access the Playground
Visit: [https://play.openpolicyagent.org/](https://play.openpolicyagent.org/)

### 2. Understanding the Interface
The playground has three main sections:
- **Policy**: Where you write your Rego code
- **Input**: Where you provide test data
- **Output**: Where you see the results

## 📝 Testing Our GitHub Release Policy

### Step 1: Copy the Policy
Copy the entire contents of `policies/github-release.rego` into the **Policy** section.

### Step 2: Copy the Policy Configuration
Copy the entire contents of `policies/policy.json` into the **Input** section.

### Step 3: Test Specific Scenarios

#### Test 1: Production Valid Deployment
```json
{
  "env": "production",
  "ref_type": "branch",
  "ref": "refs/heads/main",
  "artifact_signed": true,
  "release_controlled": true,
  "checks": {
    "tests": true
  },
  "approvers": ["user1", "user2"],
  "shared_infra": false,
  "change_recorded": true,
  "ticket_id": "CHG-123456",
  "deployment_date_agreed": true,
  "wait_elapsed_seconds": 1000,
  "now_utc": "2025-01-18T14:30:00Z",
  "is_emergency": false,
  "signed_off": true,
  "components_changed_after_signoff": false,
  "rollback_instructions_present": true,
  "deployments_today": 5
}
```

#### Test 2: Production Invalid Deployment
```json
{
  "env": "production",
  "ref_type": "branch",
  "ref": "refs/heads/feature-branch",
  "artifact_signed": false,
  "release_controlled": false,
  "checks": {
    "tests": false
  },
  "approvers": ["user1"],
  "shared_infra": true,
  "change_recorded": false,
  "ticket_id": "INVALID-123",
  "deployment_date_agreed": false,
  "wait_elapsed_seconds": 100,
  "now_utc": "2025-01-18T02:30:00Z",
  "is_emergency": false,
  "signed_off": false,
  "components_changed_after_signoff": true,
  "rollback_instructions_present": false,
  "deployments_today": 15
}
```

### Step 4: Query the Policy
In the playground, you can query different aspects of the policy:

#### Check if deployment is allowed:
```
data.policy.github.release.allow
```

#### Get all violations:
```
data.policy.github.release.deny
```

#### Check specific rule violations:
```
data.policy.github.release.controlled_tested_segregated_violations
data.policy.github.release.production_separation_violations
data.policy.github.release.documented_changes_violations
data.policy.github.release.deployment_windows_violations
data.policy.github.release.approvals_signoff_violations
data.policy.github.release.change_control_violations
data.policy.github.release.rollback_procedures_violations
data.policy.github.release.rate_limiting_guardrails
```

## 🔍 Understanding the Results

### Allowed Deployment
```json
{
  "result": true
}
```

### Denied Deployment with Violations
```json
{
  "result": [
    "CONTROLLED_TESTED_SEGREGATED_VIOLATION: Tests are required for production environment but were not executed or did not pass. Ensure all required tests are run and pass before deployment.",
    "CONTROLLED_TESTED_SEGREGATED_VIOLATION: Artifact signature verification is required for production environment but the artifact is not signed. Ensure all artifacts are properly signed before deployment."
  ]
}
```

## 🛠️ Advanced Testing

### Testing Different Environments
Change the `env` field to test different environments:
- `"production"` - Strictest rules
- `"staging"` - Moderate rules
- `"development"` - Relaxed rules

### Testing Edge Cases
- Emergency deployments (`"is_emergency": true`)
- Different ticket formats
- Various approval counts
- Different deployment times

## 📊 Policy Analysis

### Rule Coverage Testing
Test each rule individually by creating inputs that violate only one rule at a time.

### Environment Comparison
Compare how the same input behaves across different environments.

### Performance Testing
Test with large inputs to see how the policy performs.

## 🚨 Common Issues

### Syntax Errors
- Check for missing `if` keywords
- Ensure proper function calls
- Verify JSON syntax in input

### Policy Logic Issues
- Verify rule conditions
- Check helper functions
- Ensure proper variable references

### Input Validation
- Check required fields
- Verify data types
- Ensure proper structure

## 💡 Tips for Effective Testing

1. **Start Simple**: Test basic cases first
2. **Test Edge Cases**: Include boundary conditions
3. **Validate All Rules**: Ensure each rule is tested
4. **Use Descriptive Inputs**: Make test data meaningful
5. **Document Results**: Keep track of what you've tested

## 🔗 Sharing and Collaboration

### Export Policy
Use the "Share" button to get a URL that others can use to view and test your policy.

### Import Policy
Paste a shared URL to load someone else's policy for testing or modification.

### Version Control
The playground is great for prototyping, but remember to save your final policies to your repository.

## 📚 Additional Resources

- [Rego Language Documentation](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [OPA Examples](https://www.openpolicyagent.org/docs/latest/examples/)
- [Rego Best Practices](https://www.openpolicyagent.org/docs/latest/policy-language/#best-practices)

## 🎯 Next Steps

After testing in the playground:
1. Fix any issues found
2. Update your local policy files
3. Run the Python validation scripts
4. Commit and push your changes
5. Let the GitHub Actions workflow validate everything
