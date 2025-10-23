# 🧩 Governant — Policy Engine & Rego Integration Guide

![OPA](https://img.shields.io/badge/Open%20Policy%20Agent-Rego-blue)
![Governance](https://img.shields.io/badge/Governance-as--Code-green)
![Version](https://img.shields.io/badge/version-0.1.0-lightgrey)
![Status](https://img.shields.io/badge/status-Technical%20Preview-yellow)

> **Governant Policy Engine** provides the logic layer that powers *Governance as Code*.
>
> It combines JSON Schema validation, team-based configuration, and Open Policy Agent (OPA) policies
> to deliver end-to-end deployment governance for GitHub, ArgoCD, and other DevOps platforms.

---

## 📘 Table of Contents

- [Overview](#overview)
- [Main Use Cases](#main-use-cases)
- [Architecture](#architecture)
- [Policy Layers](#policy-layers)
- [Example Policy Rules](#example-policy-rules)
- [Usage & Testing](#usage--testing)
- [Rego Playground Guide](#rego-playground-guide)
- [Common Issues](#common-issues)
- [Repository Layout](#repository-layout)
- [Next Steps](#next-steps)

---

## 🌍 Overview

The **Governant Policy Engine** is the logic layer responsible for evaluating
governance policies written in **Rego** (the Open Policy Agent language).  
It provides a robust way to enforce deployment rules and compliance checks during CI/CD processes.

It builds on the *Governant philosophy*:
> *Define your governance declaratively, validate it automatically, and enforce it confidently.*

## ❓ Why this project exists

Organizations that deploy software across environments (GitHub, Kubernetes, ArgoCD, etc.) need reliable, testable guardrails: who may deploy to production, which branches are allowed, how many approvals are required, and whether a valid ticket is referenced. Those checks are often implemented as ad-hoc scripts or scattered CI steps that are hard to maintain, reuse, and test.

Governant addresses this gap by:

- Centralizing governance rules as declarative configuration plus Rego policies under `.governant/`.
- Providing a small, testable Python runtime and CLI that can evaluate compiled policy bundles (WASM / tar) programmatically or from CI.
- Making policies easy to validate (JSON Schema), test (Rego unit tests), and run in GitHub Actions or locally.

Quick start pointers:

- Try the local demo: `examples/run_policy_wasm.py`.
- Rebuild the runtime bundle if you change policies: `./scripts/compile_github_env_protect_policy.sh`.
---

## 🚦 Main Use Cases

Governant supports two primary governance scenarios:

### 1. Pull Request Policy (`.governant/policies/github_pull_request_policy.json`, `.governant/code/github_pull_request.rego`)

This policy enforces rules on every pull request before it can be merged.

**Compliance requirements for each PR:**
- The PR must target an allowed branch for the selected environment.
- The minimum number of approvers must be met.
- If required, all commits must reference a valid ticket.
- The PR must match ticket patterns if required.

**Typical PR workflow:**
1. Contributor opens a PR.
2. CI workflow builds an input document from the PR event and policy.
3. Governant evaluates the PR against the policy:
   - If all rules pass, the PR is marked as compliant.
   - Violations are reported in the workflow logs and as a GitHub Check.

### 2. Deployment Protection Policy (`.governant/policies/github_env_protect_policy.json`, `.governant/code/github_env_protect.rego`)

This policy governs deployments to protected environments (e.g., `production`, `staging`).

**Compliance requirements for each deployment:**
- The deployment must target an allowed branch for the environment.
- The required number of approvals must be present.
- A valid ticket reference must be provided if required.
- All tests must pass if required.
- The number of deployments per day must not exceed the configured limit.

**Typical deployment workflow:**
1. A workflow triggers a deployment to an environment (e.g., `production`).
2. The workflow builds an input document including environment, branch, ticket refs, approvals, test status, and deployment count.
3. Governant evaluates the deployment against the policy:
   - If all rules pass, the deployment proceeds.
   - Violations are reported and the deployment is blocked.

---

## 🧱 Architecture

Governant’s policy enforcement model uses a **three-layer architecture**:

```
┌──────────────────────────────┐
│ .governant/policies/*         │
│  → Team configuration         │
│  (Declarative Rules)          │
└───────────────┬──────────────┘
                │
┌───────────────▼──────────────┐
│ .governant/schemas/*          │
│  → Schema validation          │
│  (Structure & Type Checking)  │
└───────────────┬──────────────┘
                │
┌───────────────▼──────────────┐
│ .governant/code/*.rego        │
│  → Policy logic               │
│  (OPA Rules / Enforcement)    │
└──────────────────────────────┘
```

Each layer serves a distinct purpose:

| Layer | Responsibility | Tooling |
|--------|----------------|---------|
# Governant — Policy Engine & Rego integration

Small, testable policy runtime that evaluates Open Policy Agent (Rego)
policies configured in the repository under `/.governant/`.

This README is a concise reference for maintainers: quickstart commands,
where policies live, and how to validate and run checks locally or in CI.

## Quick start (local)

Prerequisites: Python 3.8+, the OPA CLI (for local Rego checks), and either
Poetry or pip to install dependencies.

```bash
# create a venv and activate it (recommended)
python -m venv .venv
source .venv/bin/activate

# install deps (use poetry or pip)
poetry install    # or: pip install -e .[dev]

# compile the policy bundle if you change Rego or schemas
./scripts/compile_github_env_protect_policy.sh

# run a quick check with the Python CLI wrapper
python -m opawasm.cli allow -i test-inputs/production-valid.json --artifact .compile/github_env_protect.tar.gz --package github.deploy --strict-exit

# or run OPA directly for fast local checks
opa eval --data .governant/code/github_env_protect.rego --input test-inputs/production-valid.json "data.github.deploy.allow"
```

## Where things live

- `.governant/`
  - `policies/` — declarative policy configuration (JSON)
  - `schemas/` — JSON Schema files used to validate policies
  - `code/` — Rego policy logic and Rego unit tests
- `scripts/` — helpers to validate, compile and test policies
- `test-inputs/` — small input examples used by tests and manual checks
- `src/` — Python runtime and CLI (PolicyEngine wrapper)

## Common commands

- Validate Rego files:

```bash
opa check .governant/code/*.rego
```

- Validate policy JSON against schema:

```bash
./scripts/validate_schema.sh
```

- Compile bundle used by the Python runtime (creates `.compile/*.tar.gz`):

```bash
./scripts/compile_github_env_protect_policy.sh
```

- Run tests:

```bash
poetry run pytest -v
```

## Useful scripts

The `scripts/` directory contains small helpers used during development and CI. Each script is documented with usage at the top.

- `scripts/docker-build.sh` — Build the repository Docker image.
  - Usage: `./scripts/docker-build.sh [image-name]`

- `scripts/github-environment-protect-check.sh` — Evaluate the environment protection policy against an input JSON.
  - Usage: `./scripts/github-environment-protect-check.sh test-inputs/production-valid.json`

- `scripts/github-pull-request-check.sh` — Evaluate the pull request policy against an input JSON.
  - Usage: `./scripts/github-pull-request-check.sh test-inputs/pr_valid.json`

- `scripts/run-deploy-policy-check.sh` — Run a local deployment policy check (convenience wrapper).
  - Usage: `./scripts/run-deploy-policy-check.sh test-inputs/production-valid.json`

If you add or rename scripts, keep this section and the examples in sync.

## Enforcing CODEOWNERS reviews

You already have a CODEOWNERS file that assigns `/.governant/**` to the
GitHub team `@erasmo-dominguez-stuff/governant-admin`. To require that team
to approve PRs touching that directory, enable branch protection on the
target branch (for example `main` or `development`) and check:

- "Require pull request reviews before merging"
- "Require review from Code Owners"

Branch protection is managed in the repository settings → Branches. If you
want I can add an example `branch-protection.yml` workflow (requires an
admin to apply) that documents the settings.

## Troubleshooting & tips

- If the Python WASM runtime raises "engine not found" locally, use the OPA
  CLI (`opa eval --bundle <dir> ...`) or re-generate the bundle with the
  compile script.
- Prefer the compiled bundle (`.compile/*.tar.gz`) in CI. The Python CLI
  supports `--artifact` and `--package` flags to point to the bundle and
  entrypoint.

## Contributing

- Run linters and pre-commit hooks before pushing. Example:

```bash
pre-commit install
pre-commit run --all-files
```

- Add new policy rules under `.governant/code/` and corresponding schema
  updates under `.governant/schemas/`. Use `./scripts/compile_github_env_protect_policy.sh`
  to re-generate the runtime bundle.

## Repository layout (summary)

```
├── .governant/
│   ├── code/
│   ├── schemas/
│   └── policies/
├── scripts/
├── test-inputs/
├── src/
└── .github/
```

---

MIT © 2025 Erasmo Domínguez
