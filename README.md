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

- [Overview](#-overview)
- [Architecture](#-architecture)
- [Policy Layers](#-policy-layers)
  - [1️⃣ Policy Configuration (`.gate/policy.json`)](#1️⃣-policy-configuration-gatepolicyjson)
  - [2️⃣ Schema Validation (`.gate/schema.json`)](#2️⃣-schema-validation-gateschemajson)
  - [3️⃣ Policy Logic (`.gate/*.rego`)](#3️⃣-policy-logic-gaterego)
- [Example Policy Rules](#-example-policy-rules)
- [Usage & Testing](#-usage--testing)
- [Rego Playground Guide](#-rego-playground-guide)
- [Common Issues](#-common-issues)
- [Repository Layout](#-repository-layout)
- [Next Steps](#-next-steps)

---

## 🌍 Overview

The **Governant Policy Engine** is the logic layer responsible for evaluating
governance policies written in **Rego** (the Open Policy Agent language).  
It provides a robust way to enforce deployment rules and compliance checks during CI/CD processes.

It builds on the *Governant philosophy*:
> *Define your governance declaratively, validate it automatically, and enforce it confidently.*

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
│ .gate/*.rego                  │
│  → Policy logic               │
│  (OPA Rules / Enforcement)    │
└──────────────────────────────┘
```

Each layer serves a distinct purpose:

| Layer | Responsibility | Tooling |
|--------|----------------|---------|
| **Configuration** | Define the governance intent (team’s rules). | JSON |
| **Schema Validation** | Validate structure, fields, and data types. | JSON Schema / Python |
| **Logic** | Apply governance logic, compute allow/deny decisions. | Rego (OPA) |

---

## 🧩 Policy Layers

### 1️⃣ Policy Configuration (`.gate/policy.json`)

A declarative configuration that defines what a team enforces in their repo.

> **No logic lives here — only intent.**

```json
{
  "policy": {
    "version": "1.0.0",
    "metadata": {
      "description": "Deployment governance policy for production",
      "last_updated": "2025-01-18"
    },
    "environments": {
      "production": {
        "enabled": true,
        "rules": {
          "approvals_required": 2,
          "allowed_branches": ["main"],
          "require_ticket": true,
          "ticket_pattern": "^(INC|CHG|REQ)-[0-9]{6,}$",
          "tests_passed": true,
          "signed_off": true,
          "max_deployments_per_day": 5
        }
      },
      "staging": {
        "enabled": true,
        "rules": {
          "approvals_required": 1,
          "allowed_branches": ["main", "develop"],
          "require_ticket": false,
          "tests_passed": true,
          "signed_off": false,
          "max_deployments_per_day": 20
        }
      }
    }
  }
}
```

---

### 2️⃣ Schema Validation (`.gate/schema.json`)

Defines the expected structure and data types for `policy.json`.  
Ensures all policies are well-formed before policy evaluation.

```bash
jsonschema -i .gate/policy.json .gate/schema.json
```

**Example schema excerpt:**
```json
{
  "type": "object",
  "properties": {
    "policy": {
      "type": "object",
      "properties": {
        "version": { "type": "string" },
        "environments": { "type": "object" }
      },
      "required": ["version", "environments"]
    }
  }
}
```

---

### 3️⃣ Policy Logic (`.gate/*.rego`)

Implements the actual enforcement rules using **Rego**, the Open Policy Agent (OPA) language.  
Each `.rego` file defines one or more rules that determine whether a deployment is allowed.

**Example: `github-release.rego`**
```rego
package policy.github.release

default allow = false

allow {
    input.env == "production"
    input.ref_type == "branch"
    input.ref == "refs/heads/main"
    input.artifact_signed
    input.release_controlled
    input.approvers[_]
    count(input.approvers) >= 2
    input.tests_passed
    not deny[_]
}

deny[msg] {
    input.env == "production"
    not input.tests_passed
    msg := "CONTROLLED_TESTED_SEGREGATED_VIOLATION: Tests must pass before deployment."
}
```

---

## ⚖️ Example Policy Rules

| Rule | Description |
|------|--------------|
| **Approval Requirements** | Minimum number of approvers required. |
| **Branch Authorization** | Only specific branches allowed per environment. |
| **Ticket Requirements** | Valid ticket IDs required for production. |
| **Test Requirements** | Tests must pass before deployment. |
| **Sign-off Requirements** | Sign-offs required for production releases. |
| **Rate Limiting** | Limit number of daily deployments per environment. |

---

## 🧪 Local Development & Testing

### Prerequisites

- Python 3.8+
- [OPA (Open Policy Agent)](https://www.openpolicyagent.org/docs/latest/#running-opa)
- [Poetry](https://python-poetry.org/docs/#installation) (Python dependency management)

### Quick Start

1. **Clone the repository** (if you haven't already):
   ```bash
   git clone https://github.com/your-org/governant.git
   cd governant
   ```

2. **Install dependencies**:
   ```bash
   # Install Python dependencies
   poetry install
   
   # Install OPA (if not already installed)
   curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
   chmod +x opa
   sudo mv opa /usr/local/bin/
   ```

### Testing with Scripts

We provide two main test scripts to simplify local development:

1. **Test Everything** - Runs all tests (OPA and Python):
   ```bash
   ./scripts/test_local.sh
   ```

2. **OPA Tests Only** - Focus on OPA/Rego policies:
   ```bash
   ./scripts/test_opa.sh
   ```

### Manual Testing

#### 1. Validate Schema
```bash
python scripts/validate_schema.py
```

#### 2. Run Python Tests
```bash
# Run all tests with coverage
pytest -v --cov=src --cov-report=term-missing

# Run specific test file
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

To automatically run checks before each commit, install the pre-commit hooks:

```bash
pre-commit install
```

This will run black, isort, flake8, and mypy on staged files before each commit.

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
