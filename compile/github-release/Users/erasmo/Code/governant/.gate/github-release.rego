package github.deploy

import data.github.deploy.allow
import data.github.deploy.violations

# -----------------------------------------------------------------------------
# Purpose
#   Gate GitHub deployments with an environment-aware policy:
#     - allow (boolean): final decision
#     - violations (set<object>): reasons for denial
# Entrypoints exported to WASM:
#   - github.deploy.allow
#   - github.deploy.violations
# -----------------------------------------------------------------------------

# --------- Derived configuration (defensive access) ---------------------------
env_config := input.repo_policy.policy.environments[input.environment] if {
	input.repo_policy
	input.repo_policy.policy
	input.repo_policy.policy.version
	input.repo_policy.policy.environments[input.environment]
}

rules := env_config.rules if {
	env_config
	env_config.rules
}

# -------------------- Aggregate all violations --------------------------------

# -------------------- Final decision ------------------------------------------

# =============================================================================
# 0) Policy presence and shape
# =============================================================================

policy_missing_violations contains v if {
	not input.repo_policy
	v := {"code": "policy.missing", "msg": "Missing input.repo_policy"}
}

policy_missing_violations contains v if {
	not input.repo_policy.policy
	v := {"code": "policy.missing", "msg": "Missing input.repo_policy.policy"}
}

policy_missing_violations contains v if {
	not input.repo_policy.policy.version
	v := {"code": "policy.missing", "msg": "Missing policy.version"}
}

policy_missing_violations contains v if {
	not input.repo_policy.policy.environments
	v := {"code": "environment.not_configured", "msg": sprintf("No environments configured for %q", [input.environment])}
}

policy_missing_violations contains v if {
	not input.repo_policy.policy.environments[input.environment]
	v := {"code": "environment.not_configured", "msg": sprintf("Environment %q not configured in policy", [input.environment])}
}

# =============================================================================
# 1) Environment must exist in the repo and be enabled in the policy
# =============================================================================

environment_missing_violations contains v if {
	env_config
	env_config.enabled
	not env_in_repo(input.environment, input.repo_environments)
	v := {"code": "env.missing", "msg": sprintf("Environment %q not defined in repository", [input.environment])}
}

environment_missing_violations contains v if {
	env_config
	not env_config.enabled
	v := {"code": "env.disabled", "msg": sprintf("Environment %q is disabled in policy", [input.environment])}
}

# =============================================================================
# 2) Branch allowlist (null disables the check)
# =============================================================================

branch_violations contains v if {
	rules
	rules.allowed_branches != null
	not branch_allowed(rules.allowed_branches, input.ref)
	v := {
		"code": "ref.denied",
		"msg": sprintf(
			"Branch %s not allowed for environment %s. Allowed: %v",
			[input.ref, input.environment, rules.allowed_branches],
		),
	}
}

# =============================================================================
# 3) Ticket requirement
# =============================================================================

ticket_violations contains v if {
	rules
	rules.require_ticket
	not valid_ticket(safe_array(input.workflow_meta.ticket_refs), string_or_empty(rules.ticket_pattern))
	v := {
		"code": "ticket.missing",
		"msg": sprintf(
			"Valid ticket required for %s environment. Expected pattern: %s",
			[input.environment, rules.ticket_pattern],
		),
	}
}

# =============================================================================
# 4) Approval requirement
# =============================================================================

approval_violations contains v if {
	rules
	rules.approvals_required > 0
	approvers := safe_array(input.workflow_meta.approvers)
	count(approvers) < rules.approvals_required
	v := {
		"code": "approvals.insufficient",
		"msg": sprintf(
			"Environment %s requires %d approvers, but only %d provided",
			[input.environment, rules.approvals_required, count(approvers)],
		),
	}
}

# =============================================================================
# 5) Tests must pass
# =============================================================================

test_violations contains v if {
	rules
	rules.tests_passed
	not has_tests_true(input.workflow_meta)
	v := {"code": "tests.failed", "msg": sprintf("Tests must pass for %s environment deployment", [input.environment])}
}

# =============================================================================
# 6) Sign-off required
# =============================================================================

signoff_violations contains v if {
	rules
	rules.signed_off
	not truthy(input.workflow_meta.signed_off)
	v := {"code": "signoff.missing", "msg": sprintf("Sign-off required for %s environment deployment", [input.environment])}
}

# =============================================================================
# 7) Rate limiting (max deployments per day)
# =============================================================================

rate_limit_violations contains v if {
	rules
	rules.max_deployments_per_day > 0
	dtoday := number_or_zero(input.workflow_meta.deployments_today)
	dtoday > rules.max_deployments_per_day
	v := {
		"code": "rate_limit.exceeded",
		"msg": sprintf(
			"Daily deployment limit exceeded for %s. Max: %d, Attempted: %d",
			[input.environment, rules.max_deployments_per_day, dtoday],
		),
	}
}

# -----------------------------------------------------------------------------
# Helpers (Rego v1 style — robust & explicit)
# -----------------------------------------------------------------------------

# Is the target environment present in the repository?
env_in_repo(env, repo_envs) if {
	some e in safe_array(repo_envs)
	e == env
}

# Is the ref branch allowlisted?
branch_allowed(allowed, ref) if {
	some b in safe_array(allowed)
	ref == sprintf("refs/heads/%s", [b])
}

# Ticket helpers: either any ticket (pattern == "") or one matching the regex.
valid_ticket(tickets, pattern) if {
	pattern == ""
	count(tickets) > 0
}

valid_ticket(tickets, pattern) if {
	pattern != ""
	some t in tickets
	regex.match(pattern, t)
}

# Tests must exist and be strictly true.
has_tests_true(wf) if {
	wf
	wf.checks
	truthy(wf.checks.tests)
}

# Strict boolean truthiness (no coercion):
truthy(x) if x == true

# ---------------------- Safe casters (no 'or' inside if) ----------------------

# array
safe_array(x) := x if {
	x != null
	type_name(x) == "array"
}

safe_array(x) := [] if x == null

safe_array(x) := [] if {
	x != null
	type_name(x) != "array"
}

# string
string_or_empty(x) := x if {
	x != null
	type_name(x) == "string"
}

string_or_empty(x) := "" if x == null

string_or_empty(x) := "" if {
	x != null
	type_name(x) != "string"
}

# number
number_or_zero(x) := x if {
	x != null
	type_name(x) == "number"
}

number_or_zero(x) := 0 if x == null

number_or_zero(x) := 0 if {
	x != null
	type_name(x) != "number"
}
