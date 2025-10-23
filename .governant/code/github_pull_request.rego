package github.pullrequest

import rego.v1

# =========================
# Final decision
# =========================
# Default deny. Allow only if there are zero violations.
default allow := false

allow if count(violations) == 0

# =========================
# Aggregated violations
# =========================
# We aggregate violations from specialized rule sets. Each rule family
# appends one or more entries into 'violations'.
violations contains v if v := policy_missing_violations[_]
violations contains v if v := environment_missing_violations[_]
violations contains v if v := branch_violations[_]
violations contains v if v := approval_violations[_]
violations contains v if v := signoff_violations[_]

# =========================
# Derived configuration
# =========================
# If the policy and the requested environment exist, resolve the env config.
env_config := input.repo_policy.policy.environments[input.environment] if {
	has_env_in_policy(input)
}

# Rules block under the environment (may contain allowed_branches, approvals_required, signed_off).
rules := env_config.rules if {
	env_config
	env_config.rules
}

# =========================
# Business rules
# =========================

# 1) Policy must exist and include the target environment.
policy_missing_violations contains v if {
	not has_env_in_policy(input)
	v := {"code": "policy.missing", "msg": sprintf("Policy or environment %q missing in repo_policy", [input.environment])}
}

# 2) If the environment is enabled in the policy, optionally require it to exist
#    in the repository's environments depending on 'require_repo_environment'.
#    Default behavior is strict (require_repo_environment = true) unless explicitly set to false.
environment_missing_violations contains v if {
	env_config
	env_config.enabled
	require_repo_env(env_config) # <- computed boolean (default true)
	not env_in_repo(input.environment, input.repo_environments)
	v := {"code": "env.missing", "msg": sprintf("Environment %q not defined in repository settings", [input.environment])}
}

# 3) The PR branch must be in the allowed list (accepts either 'refs/heads/X' or 'X').
branch_violations contains v if {
	rules
	rules.allowed_branches != null
	not branch_allowed(rules.allowed_branches, input.ref)
	v := {"code": "ref.denied", "msg": sprintf("Branch %s not allowed for environment %s. Allowed: %v", [input.ref, input.environment, rules.allowed_branches])}
}

# 4) Approvals: require a minimum number of distinct approvers (array of logins).
approval_violations contains v if {
	rules
	rules.approvals_required > 0
	approvers := safe_array(input.workflow_meta.approvers)
	count(approvers) < rules.approvals_required
	v := {"code": "approvals.insufficient", "msg": sprintf("Environment %s requires %d approvers, but only %d provided", [input.environment, rules.approvals_required, count(approvers)])}
}

# 5) Sign-off: require DCO-style sign-off boolean if configured.
signoff_violations contains v if {
	rules
	rules.signed_off
	not truthy(input.workflow_meta.signed_off)
	v := {"code": "signoff.missing", "msg": sprintf("Sign-off required for %s environment deployment", [input.environment])}
}

# =========================
# Helpers
# =========================

# Decide whether repo environment must exist. Default to true (strict) unless explicitly set to false.
require_repo_env(c) := b if {
	b := bool_or_default(c.require_repo_environment, true)
}

# Check that the policy and the requested environment exist.
has_env_in_policy(inp) if {
	inp.repo_policy
	inp.repo_policy.policy
	inp.repo_policy.policy.version
	inp.repo_policy.policy.environments[inp.environment]
}

# Verify the environment is present among repository-defined environments.
env_in_repo(env, repo_envs) if {
	some e in safe_array(repo_envs)
	e == env
}

# Accept either 'refs/heads/X' or 'X'.
branch_allowed(allowed, ref) if {
	some b in safe_array(allowed)
	ref == sprintf("refs/heads/%s", [b])
} else if {
	some b in safe_array(allowed)
	ref == b
}

# Strict boolean truthiness used by sign-off rule.
truthy(x) if x == true

# ---------- Type Guards ----------
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

# ---------- Safe Casters ----------
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

# ---------- Small utilities ----------
# Return x if it's a boolean, otherwise return default 'd'
bool_or_default(x, d) := x if {
	x != null
	type_name(x) == "boolean"
}

bool_or_default(x, d) := d if x == null

bool_or_default(x, d) := d if {
	x != null
	type_name(x) != "boolean"
}