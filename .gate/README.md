
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

1. Add rule logic to `.gate/github-release.rego`
2. Update the deny aggregator
3. Add rule configuration to `.gate/policy.json`
4. Create test scenarios in `test-inputs/`
