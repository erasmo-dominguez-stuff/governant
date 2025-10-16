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

---

## 🚦 Main Use Cases

Governant supports two primary governance scenarios:

### 1. Pull Request Policy (`.gate/github_pull_request_policy.json`, `.gate/github_pull_request.rego`)

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

### 2. Deployment Protection Policy (`.gate/github_env_protect_policy.json`, `.gate/github_env_protect.rego`)

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
│ .gate/policy.json            │
│  → Team configuration         │
│  (Declarative Rules)          │
└───────────────┬──────────────┘
                │
┌───────────────▼──────────────┐
│ .gate/schema.json             │
│  → Schema validation          │
│  (Structure & Type Checking)  │
└───────────────┬──────────────┘
                │
┌───────────────▼──────────────┐
│ .gate/*.rego                  │å
│  → Policy logic               │
│  (OPA Rules / Enforcement)    │
└──────────────────────────────┘
```

Each layer serves a distinct purpose:

| Layer | Responsibility | Tooling |
|--------|----------------|---------|
# Governant — Policy Engine (OPA) for GitHub/CI

This repository wraps OPA (Rego) policies with a small Python runtime and a CLI
to evaluate policies from CI or programmatically.

The README below is aligned with the files currently present in the repo.

## Key files and directories

- `.gate/`
  - `github_env_protect_policy.json` — declarative policy configuration
  - `github_env_protect_schema.json` — JSON Schema for the policy config
  - `github_env_protect.rego` — Rego rules for environment protection
  - `github_pull_request_policy.json` — PR policy configuration
  - `github_pull_request.rego` — Rego rules for PR validation
  - `github_pull_request_test.rego` — test helpers / test policy

- `src/opawasm/`
  - `main.py` — `PolicyEngine` wrapper around `opa-wasm` runtime
  - `cli.py` — CLI entrypoint (`policy`), supports `allow`, `violations`, `eval`, `version`

- `scripts/`
  - `compile_github_env_protect_policy.sh` — build the bundle into `.compile/`
  - `validate_github_env_protect_rego.sh` — run `opa` checks for Rego files
  - `validate_schema.sh` — validate JSON policy vs schema (uses `jq` or `check-jsonschema`)

- `test-inputs/` — sample input documents used by tests and manual `opa eval`
  - `production-valid.json`, `production-invalid.json`, `pr_valid.json`, `pr_no_valid.json`

## Requirements

- Python 3.8+
- Poetry (recommended) or install dependencies from `pyproject.toml`
- OPA CLI for Rego checks and manual evaluation

## Quick commands

```bash
# install dependencies
poetry install

# run Python tests
poetry run pytest -v

# run the CLI with a sample input (returns allow/deny)
poetry run python -m opawasm.cli allow -i test-inputs/production-valid.json

# check Rego syntax
opa check .gate/*.rego

# evaluate a specific policy with OPA (manual)
opa eval --data .gate/github_env_protect.rego --input test-inputs/production-valid.json "data.policy.github.release.allow"

# validate policy JSON against schema (script)
./scripts/validate_schema.sh

# (re)generate the WASM/tar bundle used by PolicyEngine
./scripts/compile_github_env_protect_policy.sh
```

## Notes for maintainers and contributors

- `PolicyEngine` (in `src/opawasm/main.py`) expects a bundle path by default:
  `.compile/github_env_protect.tar.gz`. If the bundle is missing, generate it
  using `scripts/compile_github_env_protect_policy.sh`.

- The `opa-wasm` Python package has changed APIs across releases. `PolicyEngine`
  contains heuristics to initialize the runtime from either a bundle or a single
  wasm file (e.g. `from_bundle`, `from_wasm_file`, `path`, `wasm`). If you bump
  `opa-wasm`, update the initialization code in `main.py` accordingly.

- CLI entrypoints are normalized to the `data.*` form. The CLI accepts
  `github/deploy/allow`, `github.deploy.allow` or `data.github.deploy.allow`.

- For CI gates use `--strict-exit` with `allow`/`violations` to produce a
  non-zero exit code when the policy denies or returns violations.

## How to run validation locally

1. Run unit tests:

```bash
poetry run pytest -v
```

2. Validate Rego files and schema before committing:

```bash
./scripts/validate_github_env_protect_rego.sh
./scripts/validate_schema.sh
```

3. Rebuild the bundle used by `PolicyEngine` if you changed policies:

```bash
./scripts/compile_github_env_protect_policy.sh
```

## Example GitHub Actions snippet (minimal)

This example uses `opa` directly for a quick check. Replace with the CLI
(`policy allow ... --artifact ... --strict-exit`) if you prefer to run the
Python wrapper in CI.

```yaml
jobs:
  policy-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate Governance Policy
        run: |
          opa eval --data .gate/github_env_protect.rego \
                   --input test-inputs/production-valid.json \
                   "data.policy.github.release.allow"
```

## Rego Playground

Use https://play.openpolicyagent.org/ to iteratively test policies. Query
using `data.policy.*` (for example `data.policy.github.release.allow`).

## Example inputs

Valid example (short):

```json
{
  "env": "production",
  "ref_type": "branch",
  "ref": "refs/heads/main",
  "approvers": ["user1", "user2"],
  "tests_passed": true
}
```

Invalid example (short):

```json
{
  "env": "production",
  "ref": "refs/heads/feature-branch",
  "approvers": ["user1"],
  "tests_passed": false
}
```

## Common issues

| Type | Description | Resolution |
|------|-------------|------------|
| Syntax | Rego syntax errors | `opa check .gate/*.rego` |
| Logic | Wrong conditions or missing input fields | Use Playground + tests |
| Input | Invalid JSON structure or types | Validate with `jsonschema` or `./scripts/validate_schema.sh` |

## Repo layout (summary)

```
├── .gate/
├── scripts/
├── src/opawasm/
├── test-inputs/
└── .github/
```

---

MIT © 2025 Erasmo Domínguez

pytest tests/unit/test_validators.py -v

# Run with coverage report
pytest --cov=src --cov-report=html
open htmlcov/index.html  # View coverage report
```

#### 3. Test OPA Policies
```bash
# Validate Rego syntax
opa check .gate/*.rego

# Evaluate a specific policy
opa eval --data .gate/github-release.rego \
         --input test-inputs/production-valid.json \
         "data.policy.github.release.allow"

# Get detailed evaluation
opa eval --format pretty \
         --data .gate/github-release.rego \
         --input test-inputs/production-valid.json \
         "data.policy.github.release"
```

### Linting and Code Quality

```bash
# Run black formatter
black src/ tests/

# Check import ordering
isort src/ tests/

# Run flake8 linter
flake8 src/ tests/

# Run mypy type checking
mypy src/
```

### Pre-commit Hooks

This project includes a comprehensive pre-commit configuration that runs various checks before each commit. The hooks will automatically format, lint, and check your code for common issues.

#### Installation

1. Install pre-commit if you haven't already:
   ```bash
   pip install pre-commit
   ```

2. Install the git hooks:
   ```bash
   pre-commit install
   ```

   This will set up the git hooks to run automatically before each commit.

#### Running Manually

You can run the pre-commit checks on all files at any time with:

```bash
pre-commit run --all-files
```

To run a specific hook (e.g., black):

```bash
pre-commit run black --all-files
```

#### Available Hooks

The following hooks are configured:

- **Code Formatting**
  - `black`: Python code formatter
  - `isort`: Sorts Python imports
  - `trailing-whitespace`: Trims trailing whitespace
  - `end-of-file-fixer`: Ensures files end with a newline

- **Linting**
  - `flake8`: Python linter with several plugins
  - `mypy`: Static type checking
  - `shellcheck`: Shell script linting
  - `markdownlint`: Markdown formatting
  - `yamllint`: YAML formatting and validation

- **Security**
  - `detect-secrets`: Prevents committing sensitive data
  - `debug-statements`: Checks for debugger imports

- **Validation**
  - `check-json`: Validates JSON files
  - `check-yaml`: Validates YAML files
  - `check-toml`: Validates TOML files
  - `konstraint-validate`: Validates OPA Rego policies

#### Skipping Hooks

To skip pre-commit hooks for a single commit:

```bash
git commit --no-verify -m "Your commit message"
```

#### Updating Hooks

To update all hooks to their latest versions:

```bash
pre-commit autoupdate
```

### GitHub Action Integration

You can also test using the same environment as CI:

```yaml
jobs:
  policy-validation:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Validate Governance Policy
        run: |
          opa eval --data .gate/github-release.rego \
                   --input .gate/input.json \
                   "data.policy.github.release.allow"
```

---

## 🧮 Rego Playground Guide

The [Rego Playground](https://play.openpolicyagent.org/) is an online environment to **test policies interactively** before integrating them into Governant.

### 🧭 Getting Started

1. Visit the [Rego Playground](https://play.openpolicyagent.org/).  
2. Copy your Rego policy (e.g., `.gate/github-release.rego`) into the **Policy** section.  
3. Copy your policy input (`.gate/policy.json`) or any test case into the **Input** section.  
4. Query results using expressions such as:
   ```
   data.policy.github.release.allow
   data.policy.github.release.deny
   ```

### ✅ Example Valid Input
```json
{
  "env": "production",
  "ref_type": "branch",
  "ref": "refs/heads/main",
  "artifact_signed": true,
  "release_controlled": true,
  "approvers": ["user1", "user2"],
  "tests_passed": true,
  "ticket_id": "CHG-123456"
}
```

**Expected output:**
```json
{ "result": true }
```

### ❌ Example Invalid Input
```json
{
  "env": "production",
  "ref": "refs/heads/feature-branch",
  "approvers": ["user1"],
  "tests_passed": false
}
```

**Expected output:**
```json
{
  "result": [
    "CONTROLLED_TESTED_SEGREGATED_VIOLATION: Tests must pass before deployment."
  ]
}
```

---

## 🚨 Common Issues

| Type | Description | Resolution |
|------|--------------|-------------|
| **Syntax Errors** | Missing `if` or misaligned braces. | Run `opa check .gate/*.rego`. |
| **Logic Errors** | Incorrect condition or missing input fields. | Use Playground to inspect values. |
| **Input Validation** | Wrong JSON types or structure. | Validate with `jsonschema`. |

---

## 🗂 Repository Layout

```
├── .gate/
│   ├── github-release.rego    # Rego policy logic
│   ├── schema.json            # JSON Schema for policy.json
│   └── policy.json            # Team configuration
├── scripts/
│   ├── validate_schema.py
│   ├── execute_policy.py
│   ├── test_all_scenarios.py
│   └── benchmark_policy.py
├── test-inputs/
│   ├── production-valid.json
│   ├── production-invalid.json
│   └── staging-valid.json
└── .github/workflows/
    └── validate-policy.yml
```

---

## 🎯 Next Steps

1. Use Rego Playground for iterative testing.  
2. Validate your policies with schema checks locally.  
3. Integrate Governant’s CLI for large-scale org validation.  
4. Automate policy enforcement in CI pipelines.  
5. Contribute new rule packs and providers.

---

**MIT © 2025 [Erasmo Domínguez](https://github.com/erasmolpa)**  
Governant — *Governance as Code for real-world platforms.*