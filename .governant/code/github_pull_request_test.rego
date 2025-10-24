package github.pullrequest_test

import data.github.pullrequest as github_pullrequest
import rego.v1

# --- Define a base reusable policy for tests
base_policy := {"policy": {
	"version": "1.0",
	"environments": {"pr_validation": {
		"enabled": true,
		"require_repo_environment": false,
		"rules": {
			"allowed_branches": ["main"],
			"approvals_required": 1,
			"signed_off": false,
		},
	}},
}}

# --- Example test: should ALLOW when all conditions pass
test_allow_main_branch if {
	test_input := {
		"environment": "pr_validation",
		"ref": "refs/heads/main",
		"repo_environments": ["dev", "staging"],
		"repo_policy": base_policy,
		"workflow_meta": {
			"approvers": ["erasmo"],
			"signed_off": false,
		},
	}
	github_pullrequest.allow with input as test_input
}

# --- Example test: should DENY when branch not allowed
test_deny_branch_not_allowed if {
	test_input := {
		"environment": "pr_validation",
		"ref": "refs/heads/feature/abc",
		"repo_environments": ["dev", "staging"],
		"repo_policy": base_policy,
		"workflow_meta": {
			"approvers": ["erasmo"],
			"signed_off": false,
		},
	}
	not github_pullrequest.allow with input as test_input
}

# --- Example test: should DENY when no approvers
test_deny_missing_approvers if {
	test_input := {
		"environment": "pr_validation",
		"ref": "refs/heads/main",
		"repo_environments": ["dev", "staging"],
		"repo_policy": base_policy,
		"workflow_meta": {
			"approvers": [],
			"signed_off": false,
		},
	}
	not github_pullrequest.allow with input as test_input
}
