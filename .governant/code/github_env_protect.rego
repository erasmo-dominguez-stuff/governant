package github.deploy

# =============================================================================
#  GitHub Deployment Policy (Rego v1, WASM-friendly)
#
#  Exported entrypoints (WASM):
#    - github/deploy/allow
#    - github/deploy/violations
#
#  INPUT (subset used)
#  {
#    "environment": "production" | "staging" | "development" | ...,
#    "ref": "refs/heads/main",
#    "repo_environments": ["production","staging", ...],
#    "workflow_meta": {
#      "ticket_refs": ["REQ-123456"],
#      "approvers": ["alice","bob"],
#      "checks": { "tests": true },
#      "signed_off": true,
#      "deployments_today": 3
#    },
#    "repo_policy": { ... }  // see POLICY JSON CONTRACT below
#  }
#
#  POLICY JSON CONTRACT (subset)
#  repo_policy.policy.version : string
#  repo_policy.policy.environments[<env>].enabled : boolean
#  repo_policy.policy.environments[<env>].rules : {
#    approvals_required: number,
#    allowed_branches: [string] | null,
#    require_ticket: boolean,
#    ticket_pattern: string,
#    tests_passed: boolean,
#    signed_off: boolean,
#    max_deployments_per_day: number
#  }
# =============================================================================

# -------- Final decision --------
default allow := false

allow if count(violations) == 0

# -------- Aggregate violations --------
violations contains v if v := input_schema_violations[_]
violations contains v if v := policy_schema_violations[_]
violations contains v if v := environment_missing_violations[_]
violations contains v if v := branch_violations[_]
violations contains v if v := ticket_violations[_]
violations contains v if v := approval_violations[_]
violations contains v if v := test_violations[_]
violations contains v if v := signoff_violations[_]
violations contains v if v := rate_limit_violations[_]

# -------- Derived config (only if policy+env exist) --------
env_config := input.repo_policy.policy.environments[input.environment] if {
	has_env_in_policy(input)
}

rules := env_config.rules if {
	env_config
	env_config.rules
}

# ========== A) INPUT SCHEMA VALIDATION ==========
input_schema_violations contains v if {
	not input.environment
	v := {"code": "schema.input.missing_environment", "msg": "Missing input.environment"}
}

input_schema_violations contains v if {
	not input.ref
	v := {"code": "schema.input.missing_ref", "msg": "Missing input.ref (e.g., refs/heads/main)"}
}

input_schema_violations contains v if {
	not input.repo_environments
	v := {"code": "schema.input.missing_repo_environments", "msg": "Missing input.repo_environments (array of env names)"}
}

input_schema_violations contains v if {
	not input.workflow_meta
	v := {"code": "schema.input.missing_workflow_meta", "msg": "Missing input.workflow_meta"}
}

# optional checks
input_schema_violations contains v if {
	input.workflow_meta
	wm := input.workflow_meta
	wm.checks
	not type_bool_strict(wm.checks.tests)
	v := {"code": "schema.input.invalid_checks.tests", "msg": "workflow_meta.checks.tests must be boolean"}
}

input_schema_violations contains v if {
	input.workflow_meta
	wm := input.workflow_meta
	wm.approvers
	not is_array_of_strings(wm.approvers)
	v := {"code": "schema.input.invalid_approvers", "msg": "workflow_meta.approvers must be array of strings"}
}

input_schema_violations contains v if {
	input.workflow_meta
	wm := input.workflow_meta
	wm.ticket_refs
	not is_array_of_strings(wm.ticket_refs)
	v := {"code": "schema.input.invalid_ticket_refs", "msg": "workflow_meta.ticket_refs must be array of strings"}
}

input_schema_violations contains v if {
	input.workflow_meta
	wm := input.workflow_meta
	wm.deployments_today
	not type_number(wm.deployments_today)
	v := {"code": "schema.input.invalid_deployments_today", "msg": "workflow_meta.deployments_today must be number"}
}

# ========== B) POLICY SCHEMA VALIDATION ==========
policy_schema_violations contains v if {
	not input.repo_policy
	v := {"code": "schema.policy.missing_repo_policy", "msg": "Missing input.repo_policy"}
}

policy_schema_violations contains v if {
	input.repo_policy
	not input.repo_policy.policy
	v := {"code": "schema.policy.missing_policy", "msg": "Missing input.repo_policy.policy"}
}

policy_schema_violations contains v if {
	input.repo_policy.policy
	not type_string(input.repo_policy.policy.version)
	v := {"code": "schema.policy.missing_version", "msg": "policy.version must be string"}
}

policy_schema_violations contains v if {
	input.repo_policy.policy
	not input.repo_policy.policy.environments
	v := {"code": "schema.policy.missing_environments", "msg": "policy.environments missing"}
}

policy_schema_violations contains v if {
	input.repo_policy.policy.environments
	not input.repo_policy.policy.environments[input.environment]
	v := {"code": "schema.policy.env_not_defined", "msg": sprintf("Environment %q not found in policy.environments", [input.environment])}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	cfg := input.repo_policy.policy.environments[input.environment]
	not type_boolean(cfg.enabled)
	v := {"code": "schema.policy.env.enabled", "msg": "environments[env].enabled must be boolean"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	cfg := input.repo_policy.policy.environments[input.environment]
	not cfg.rules
	v := {"code": "schema.policy.env.rules.missing", "msg": "environments[env].rules missing"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	r := input.repo_policy.policy.environments[input.environment].rules
	not type_number(r.approvals_required)
	v := {"code": "schema.policy.rules.approvals_required", "msg": "rules.approvals_required must be number"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	r := input.repo_policy.policy.environments[input.environment].rules
	r.allowed_branches != null
	not is_array_of_strings(r.allowed_branches)
	v := {"code": "schema.policy.rules.allowed_branches", "msg": "rules.allowed_branches must be array of strings or null"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	r := input.repo_policy.policy.environments[input.environment].rules
	not type_boolean(r.require_ticket)
	v := {"code": "schema.policy.rules.require_ticket", "msg": "rules.require_ticket must be boolean"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	r := input.repo_policy.policy.environments[input.environment].rules
	not type_string(r.ticket_pattern)
	v := {"code": "schema.policy.rules.ticket_pattern", "msg": "rules.ticket_pattern must be string (empty allowed)"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	r := input.repo_policy.policy.environments[input.environment].rules
	not type_boolean(r.tests_passed)
	v := {"code": "schema.policy.rules.tests_passed", "msg": "rules.tests_passed must be boolean"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	r := input.repo_policy.policy.environments[input.environment].rules
	not type_boolean(r.signed_off)
	v := {"code": "schema.policy.rules.signed_off", "msg": "rules.signed_off must be boolean"}
}

policy_schema_violations contains v if {
	has_env_in_policy(input)
	r := input.repo_policy.policy.environments[input.environment].rules
	not type_number(r.max_deployments_per_day)
	v := {"code": "schema.policy.rules.max_deployments_per_day", "msg": "rules.max_deployments_per_day must be number"}
}

# ========== C) BUSINESS RULES ==========
environment_missing_violations contains v if {
	env_config
	env_config.enabled
	not env_in_repo(input.environment, input.repo_environments)
	v := {"code": "env.missing", "msg": sprintf("Environment %q not defined in repository", [input.environment])}
}

branch_violations contains v if {
	rules
	rules.allowed_branches != null
	not branch_allowed(rules.allowed_branches, input.ref)
	v := {"code": "ref.denied", "msg": sprintf("Branch %s not allowed for environment %s. Allowed: %v", [input.ref, input.environment, rules.allowed_branches])}
}

ticket_violations contains v if {
	rules
	rules.require_ticket
	not valid_ticket(safe_array(input.workflow_meta.ticket_refs), string_or_empty(rules.ticket_pattern))
	v := {"code": "ticket.missing", "msg": sprintf("Valid ticket required for %s environment. Expected pattern: %s", [input.environment, rules.ticket_pattern])}
}

approval_violations contains v if {
	rules
	rules.approvals_required > 0
	approvers := safe_array(input.workflow_meta.approvers)
	count(approvers) < rules.approvals_required
	v := {"code": "approvals.insufficient", "msg": sprintf("Environment %s requires %d approvers, but only %d provided", [input.environment, rules.approvals_required, count(approvers)])}
}

test_violations contains v if {
	rules
	rules.tests_passed
	not has_tests_true(input.workflow_meta)
	v := {"code": "tests.failed", "msg": sprintf("Tests must pass for %s environment deployment", [input.environment])}
}

signoff_violations contains v if {
	rules
	rules.signed_off
	not truthy(input.workflow_meta.signed_off)
	v := {"code": "signoff.missing", "msg": sprintf("Sign-off required for %s environment deployment", [input.environment])}
}

rate_limit_violations contains v if {
	rules
	rules.max_deployments_per_day > 0
	dtoday := number_or_zero(input.workflow_meta.deployments_today)
	dtoday > rules.max_deployments_per_day
	v := {"code": "rate_limit.exceeded", "msg": sprintf("Daily deployment limit exceeded for %s. Max: %d, Attempted: %d", [input.environment, rules.max_deployments_per_day, dtoday])}
}

# ========== D) Helpers ==========
# Presence check for env in policy (param NOT named 'in' — reserved)
has_env_in_policy(inp) if {
	inp.repo_policy
	inp.repo_policy.policy
	inp.repo_policy.policy.version
	inp.repo_policy.policy.environments[inp.environment]
}

env_in_repo(env, repo_envs) if {
	some e in safe_array(repo_envs)
	e == env
}

branch_allowed(allowed, ref) if {
	some b in safe_array(allowed)
	ref == sprintf("refs/heads/%s", [b])
}

valid_ticket(tickets, pattern) if {
	pattern == ""
	count(tickets) > 0
}

valid_ticket(tickets, pattern) if {
	pattern != ""
	some t in tickets
	regex.match(pattern, t)
}

has_tests_true(wf) if {
	wf
	wf.checks
	truthy(wf.checks.tests)
}

truthy(x) if x == true

# Type guards
# ------- Type guards (Rego v1: function-style rules need `if { ... }`) -------
type_string(x) if {
	x != null
	type_name(x) == "string"
}

type_number(x) if {
	x != null
	type_name(x) == "number"
}

type_boolean(x) if {
	x != null
	type_name(x) == "boolean"
}

# boolean estricto (dos reglas)
type_bool_strict(x) if x == true
type_bool_strict(x) if x == false

is_array_of_strings(arr) if {
	arr != null
	type_name(arr) == "array"
	not exists_non_string(arr)
}

exists_non_string(arr) if {
	some i
	i < count(arr)
	type_name(arr[i]) != "string"
}

# Safe casters (separate rules; avoid 'or' inside if)
safe_array(x) := x if {
	x != null
	type_name(x) == "array"
}

safe_array(x) := [] if x == null

safe_array(x) := [] if {
	x != null
	type_name(x) != "array"
}

string_or_empty(x) := x if {
	x != null
	type_name(x) == "string"
}

string_or_empty(x) := "" if x == null

string_or_empty(x) := "" if {
	x != null
	type_name(x) != "string"
}

number_or_zero(x) := x if {
	x != null
	type_name(x) == "number"
}

number_or_zero(x) := 0 if x == null

number_or_zero(x) := 0 if {
	x != null
	type_name(x) != "number"
}