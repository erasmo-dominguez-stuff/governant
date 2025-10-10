package github.deploy

# Default decision: deny by default
default allow = false

# Get environment configuration from repo policy
env_config := input.repo_policy.policy.environments[input.environment]
rules := env_config.rules

# Collect all violations with structured format
violations contains v if {
  v := policy_missing_violations[_]
}

violations contains v if {
  v := environment_missing_violations[_]
}

violations contains v if {
  v := branch_violations[_]
}

violations contains v if {
  v := ticket_violations[_]
}

violations contains v if {
  v := approval_violations[_]
}

violations contains v if {
  v := test_violations[_]
}

violations contains v if {
  v := signoff_violations[_]
}

violations contains v if {
  v := rate_limit_violations[_]
}

# Allow deployment if no violations
allow if count(violations) == 0

# 0) Policy must exist and be valid
policy_missing_violations contains v if {
  not input.repo_policy.policy.version
  v := {
    "code": "policy.missing",
    "msg": "Missing .gate/policy.json or invalid policy structure"
  }
}

policy_missing_violations contains v if {
  not input.repo_policy.policy.environments[input.environment]
  v := {
    "code": "environment.not_configured",
    "msg": sprintf("Environment %q not configured in policy", [input.environment])
  }
}

# 1) Environment must exist in repo and be enabled
environment_missing_violations contains v if {
  env_config.enabled
  not input.environment in input.repo_environments
  v := {
    "code": "env.missing",
    "msg": sprintf("Environment %q not defined in repository", [input.environment])
  }
}

environment_missing_violations contains v if {
  not env_config.enabled
  v := {
    "code": "env.disabled",
    "msg": sprintf("Environment %q is disabled in policy", [input.environment])
  }
}

# 2) Branch authorization
branch_violations contains v if {
  rules.allowed_branches != null
  not branch_allowed(rules.allowed_branches, input.ref)
  v := {
    "code": "ref.denied",
    "msg": sprintf("Branch %s not allowed for environment %s. Allowed: %v", [input.ref, input.environment, rules.allowed_branches])
  }
}

# 3) Ticket requirements
ticket_violations contains v if {
  rules.require_ticket
  not valid_ticket(input.workflow_meta.ticket_refs, rules.ticket_pattern)
  v := {
    "code": "ticket.missing",
    "msg": sprintf("Valid ticket required for %s environment. Expected pattern: %s", [input.environment, rules.ticket_pattern])
  }
}

# 4) Approval requirements
approval_violations contains v if {
  rules.approvals_required > 0
  count(input.workflow_meta.approvers) < rules.approvals_required
  v := {
    "code": "approvals.insufficient",
    "msg": sprintf("Environment %s requires %d approvers, but only %d provided", [input.environment, rules.approvals_required, count(input.workflow_meta.approvers)])
  }
}

# 5) Test requirements
test_violations contains v if {
  rules.tests_passed
  not input.workflow_meta.checks.tests
  v := {
    "code": "tests.failed",
    "msg": sprintf("Tests must pass for %s environment deployment", [input.environment])
  }
}

# 6) Sign-off requirements
signoff_violations contains v if {
  rules.signed_off
  not input.workflow_meta.signed_off
  v := {
    "code": "signoff.missing",
    "msg": sprintf("Sign-off required for %s environment deployment", [input.environment])
  }
}

# 7) Rate limiting
rate_limit_violations contains v if {
  rules.max_deployments_per_day > 0
  input.workflow_meta.deployments_today > rules.max_deployments_per_day
  v := {
    "code": "rate_limit.exceeded",
    "msg": sprintf("Daily deployment limit exceeded for %s. Max: %d, Attempted: %d", [input.environment, rules.max_deployments_per_day, input.workflow_meta.deployments_today])
  }
}

# Helper Functions

# Check if ticket is valid
valid_ticket(tickets, pattern) if {
  pattern == ""
  count(tickets) > 0
}

valid_ticket(tickets, pattern) if {
  pattern != ""
  some ticket in tickets
  regex.match(pattern, ticket)
}

# Check if branch is allowed
branch_allowed(allowed, ref) if {
  some b in allowed
  ref == sprintf("refs/heads/%s", [b])
}