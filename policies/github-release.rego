package policy.github.release

# Simplified GitHub Release Deployment Policy
# This policy enforces basic security and compliance rules for deployments

default allow = false

# Get environment rules from input
rules := data.policy.environments[input.env].rules

# Collect all violations
deny[msg] if msg := approval_violations[_]
deny[msg] if msg := branch_violations[_]
deny[msg] if msg := ticket_violations[_]
deny[msg] if msg := test_violations[_]
deny[msg] if msg := signoff_violations[_]
deny[msg] if msg := rate_limit_violations[_]

# Allow deployment if no violations
allow if count(deny) == 0

# Rule 1: Approval Requirements
approval_violations[msg] if {
  rules.approvals_required > 0
  count(input.approvers) < rules.approvals_required
  msg := sprintf("APPROVAL_VIOLATION: %s environment requires %d approvers, but only %d provided", [input.env, rules.approvals_required, count(input.approvers)])
}

# Rule 2: Branch Authorization
branch_violations[msg] if {
  rules.allowed_branches != null
  input.ref_type == "branch"
  not branch_allowed(rules.allowed_branches, input.ref)
  msg := sprintf("BRANCH_VIOLATION: Branch %s not allowed for %s environment. Allowed: %v", [input.ref, input.env, rules.allowed_branches])
}

# Rule 3: Ticket Requirements
ticket_violations[msg] if {
  rules.require_ticket
  not valid_ticket(input.ticket_id, rules.ticket_pattern)
  msg := sprintf("TICKET_VIOLATION: Valid ticket required for %s environment. Expected format: %s", [input.env, rules.ticket_pattern])
}

# Rule 4: Test Requirements
test_violations[msg] if {
  rules.tests_passed
  not input.checks.tests
  msg := sprintf("TEST_VIOLATION: Tests must pass for %s environment deployment", [input.env])
}

# Rule 5: Sign-off Requirements
signoff_violations[msg] if {
  rules.signed_off
  not input.signed_off
  msg := sprintf("SIGNOFF_VIOLATION: Sign-off required for %s environment deployment", [input.env])
}

# Rule 6: Rate Limiting
rate_limit_violations[msg] if {
  rules.max_deployments_per_day > 0
  input.deployments_today > rules.max_deployments_per_day
  msg := sprintf("RATE_LIMIT_VIOLATION: Daily deployment limit exceeded for %s. Max: %d, Attempted: %d", [input.env, rules.max_deployments_per_day, input.deployments_today])
}

# Helper Functions

# Check if ticket is valid
valid_ticket(t, pat) if {
  t != ""
  pat == ""
}

valid_ticket(t, pat) if {
  t != ""
  regex.match(pat, t)
}

# Check if branch is allowed
branch_allowed(allowed, ref) if {
  some b in allowed
  ref == sprintf("refs/heads/%s", [b])
}