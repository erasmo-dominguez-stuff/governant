package policy

import future.keywords.in

default allow = false

# Reglas de ejemplo - Ajusta según tus necesidades
allow {
    not count(violations) > 0
}

# Recolectar todas las violaciones
violations[reason] {
    some i
    reason := branch_violations[i]
}

violations[reason] {
    some i
    reason := ticket_violations[i]
}

violations[reason] {
    some i
    reason := approval_violations[i]
}

violations[reason] {
    some i
    reason := test_violations[i]
}

violations[reason] {
    some i
    reason := signoff_violations[i]
}

violations[reason] {
    some i
    reason := rate_limit_violations[i]
}

# Reglas de validación (ajusta según tus necesidades)
branch_violations[msg] {
    input.environment == "production"
    not startswith(input.ref, "refs/heads/release/")
    msg := "Production deployments must be from release/* branches"
}

ticket_violations[msg] {
    input.environment == "production"
    not [ticket | ticket = input.workflow_meta.ticket_refs[_]; startswith(ticket, "PROJ-")]
    msg := "Production deployments require a valid ticket reference (e.g., PROJ-123)"
}

approval_violations[msg] {
    input.environment == "production"
    count(input.workflow_meta.approvers) < 2
    msg := "Production deployments require at least 2 approvals"
}

test_violations[msg] {
    input.environment == "production"
    not input.workflow_meta.tests_passed
    msg := "All tests must pass for production deployments"
}

signoff_violations[msg] {
    input.environment == "production"
    not input.workflow_meta.signed_off
    msg := "Production deployments require sign-off"
}

rate_limit_violations[msg] {
    input.workflow_meta.deployments_today >= 3
    msg := "Maximum daily deployments (3) reached"
}
