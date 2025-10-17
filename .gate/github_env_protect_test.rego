package github.deploy_test

# Load fixtures from test-inputs using `input` local variables in each test.

test_allow_production_valid if {
    inp := {
        "environment": "production",
        "ref": "refs/heads/main",
        "repo_environments": ["production","staging"],
        "workflow_meta": {
            "ticket_refs": ["REQ-123456"],
            "approvers": ["alice","bob"],
            "checks": {"tests": true},
            "signed_off": true,
            "deployments_today": 1
        },
        "repo_policy": {
            "policy": {
                "version": "1.0.0",
                "environments": {
                    "production": {
                        "enabled": true,
                        "rules": {
                            "approvals_required": 2,
                            "allowed_branches": ["main"],
                            "require_ticket": true,
                            "ticket_pattern": "^(REQ|INC)-[0-9]{6,}$",
                            "tests_passed": true,
                            "signed_off": true,
                            "max_deployments_per_day": 5
                        }
                    }
                }
            }
        }
    }

    # no violations -> allow true
    vs := data.github.deploy.violations with input as inp
    count(vs) == 0
    allow := data.github.deploy.allow with input as inp
    allow == true
}

test_missing_ticket_results_in_ticket_violation if {
    inp := {
        "environment": "production",
        "ref": "refs/heads/main",
        "repo_environments": ["production"],
        "workflow_meta": {
            "ticket_refs": [],
            "approvers": ["alice","bob"],
            "checks": {"tests": true},
            "signed_off": true,
            "deployments_today": 0
        },
        "repo_policy": {
            "policy": {
                "version": "1.0.0",
                "environments": {
                    "production": {
                        "enabled": true,
                        "rules": {
                            "approvals_required": 2,
                            "allowed_branches": ["main"],
                            "require_ticket": true,
                            "ticket_pattern": "^(REQ|INC)-[0-9]{6,}$",
                            "tests_passed": true,
                            "signed_off": true,
                            "max_deployments_per_day": 5
                        }
                    }
                }
            }
        }
    }

    vs := data.github.deploy.violations with input as inp
    some i
    vs[i].code == "ticket.missing"
}

test_branch_not_allowed_produces_ref_denied if {
    inp := {
        "environment": "production",
        "ref": "refs/heads/feature/xyz",
        "repo_environments": ["production"],
        "workflow_meta": {
            "ticket_refs": ["REQ-123456"],
            "approvers": ["alice","bob"],
            "checks": {"tests": true},
            "signed_off": true,
            "deployments_today": 0
        },
        "repo_policy": {
            "policy": {
                "version": "1.0.0",
                "environments": {
                    "production": {
                        "enabled": true,
                        "rules": {
                            "approvals_required": 2,
                            "allowed_branches": ["main"],
                            "require_ticket": true,
                            "ticket_pattern": "^(REQ|INC)-[0-9]{6,}$",
                            "tests_passed": true,
                            "signed_off": true,
                            "max_deployments_per_day": 5
                        }
                    }
                }
            }
        }
    }

    vs := data.github.deploy.violations with input as inp
    some i
    vs[i].code == "ref.denied"
}
