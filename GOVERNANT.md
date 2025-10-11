# 🧭 Governant — Governance as Code Framework

![License](https://img.shields.io/badge/license-MIT-green.svg)
![Build](https://img.shields.io/github/actions/workflow/status/governant-project/governant-cli/ci.yml?label=build)
![Version](https://img.shields.io/badge/version-0.1.0-blue)
![Platform](https://img.shields.io/badge/platform-GitHub%20%7C%20ArgoCD%20%7C%20Terraform-lightgrey)
![Status](https://img.shields.io/badge/status-vision%20%26%20MVP%20phase-yellow)

> **Governant** turns organizational policies into declarative, testable, and auditable code.  
> *Because governance should be composable, automated, and developer‑friendly.*

---

## Table of Contents
- [Overview](#-overview)
- [Key Features](#-key-features)
- [Philosophy](#-philosophy)
- [Architecture](#-architecture)
- [Policy Model](#-policy-model)
- [Quick Start](#-quick-start)
- [CLI Commands](#-cli-commands)
- [Examples](#-examples)
- [Integrations](#-integrations)
- [Repository Structure](#-repository-structure)
- [Roadmap](#-roadmap)
- [Contributing](#-contributing)
- [Security](#-security)
- [Versioning](#-versioning)
- [License](#-license)
- [Credits & Inspiration](#-credits--inspiration)

---

## 🌍 Overview

**Governant** is an open‑source framework that transforms platform governance into code.  
It enables organizations to define and enforce policies — such as branch protection, environment approvals, secret management, and workflow checks — across DevOps platforms like **GitHub**, **ArgoCD**, and **Terraform**.

Instead of relying on documentation, meetings, or manual reviews, Governant brings **compliance and control directly into your pipelines** with validations, reports, and optional automatic remediation via Pull Requests.

---

## ✨ Key Features

| Category | Description |
|-----------|-------------|
| 🧩 **Declarative Governance** | Define policies as YAML/JSON, validated by JSON Schema. |
| 🔍 **Validation Engine** | Evaluate repositories, environments, rulesets, and pipelines. |
| 🔐 **Enforcement** | Fail builds or run in audit‑only mode; optional autofix via PRs. |
| 🧪 **Preflight Checks** | Lint policies and simulate validations locally (dry‑run). |
| 📊 **Reporting** | Emit JSON/HTML/Markdown reports; export SARIF for code scanning. |
| ⚙️ **Extensible Providers** | Providers for GitHub, ArgoCD, Terraform (more coming). |
| 🧱 **Composability** | Reusable rule packs, shared org baselines, team overrides. |
| 🧭 **Traceability** | Every rule change is versioned and reviewable like code. |

---

## 🧠 Philosophy

> “Governance should be an engineering discipline — not a bureaucracy.”

Governant embraces five principles:

1. **Declarative over procedural** — describe *what* must hold true, not *how* to enforce it.  
2. **Composability** — small, reusable rule blocks that can be assembled per team/env.  
3. **Transparency** — governance lives in the repo; every change is a diff.  
4. **Autonomy** — teams have freedom within safe, well‑defined boundaries.  
5. **Auditability** — compliance is observable, measurable, and reproducible.

---

## 🧱 Architecture

```
┌───────────────────────────────────────────┐
│              Governant CLI                │
│  (define • validate • enforce • report)   │
└───────────────────────────────────────────┘
                │
                ▼
     ┌──────────────────────────┐
     │    Governance Engine     │
     │  • Policy schema loader  │
     │  • Rule evaluator        │
     │  • Provider orchestrator │
     └──────────────────────────┘
        │            │           │
        ▼            ▼           ▼
   GitHub Provider  ArgoCD     Terraform
   (repos, envs,    Provider   Provider
    rulesets)       (apps)     (state)
```

- **CLI** — entry point to validate, report, and remediate.  
- **Engine** — parses policies, resolves rule packs, runs evaluators.  
- **Providers** — implement resource discovery & actions for each tool.

---

## 📐 Policy Model

Policies are small, composable, and versioned. They can import **rule packs** and allow **team overrides**.

### Example Policy (YAML)

```yaml
version: 1.0.0
metadata:
  id: production-governance
  description: Governance rules for production environments
  owners: ["platform@company.com"]
imports:
  - ./rulepacks/github_baseline.yaml
  - ./rulepacks/security_minimum.yaml
selector:
  provider: github
  org: schroder-engineering
rules:
  approvals_required: 2
  allowed_branches: ["main"]
  require_ticket: true
  ticket_pattern: "^(CHG|REQ|INC)-[0-9]{6,}$"
  tests_passed: true
  max_deployments_per_day: 5
overrides:
  team: "data-platform"
  rules:
    max_deployments_per_day: 8  # exception approved for this team
```

### JSON Schema (excerpt)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Governant Policy",
  "type": "object",
  "required": ["version", "metadata", "rules"],
  "properties": {
    "version": { "type": "string" },
    "metadata": {
      "type": "object",
      "required": ["id", "description"],
      "properties": {
        "id": { "type": "string" },
        "description": { "type": "string" },
        "owners": { "type": "array", "items": { "type": "string" } }
      }
    },
    "imports": { "type": "array", "items": { "type": "string" } },
    "selector": { "type": "object" },
    "rules": { "type": "object" },
    "overrides": { "type": "object" }
  }
}
```

---

## 🚀 Quick Start

### 1) Install

**Python (pip):**
```bash
pip install governant
```

**Docker:**
```bash
docker run --rm -it -v $PWD:/work ghcr.io/governant-project/governant-cli:latest   governant --help
```

### 2) Validate your org

```bash
governant validate   --policy ./policies/production.yaml   --provider github   --org schroder-engineering
```

**Sample Output**
```
✔ devops-toolchain → compliant
✖ legacy-app → violations (2)
   - allowed_branches: branch 'main' not protected
   - approvals_required: expected 2, found 0
----------------------------------------------
Summary: 14 compliant | 2 with violations
Report: ./reports/governant_2025-10-11.json
Exit code: 1
```

### 3) Produce a report

```bash
governant report ./reports/governant_last.json --format html --out ./reports/index.html
```

### 4) Autofix (optional, experimental)

```bash
governant fix --policy ./policies/production.yaml --provider github --org schroder-engineering
# Opens PRs with branch protection/ruleset changes where possible
```

---

## 🧰 CLI Commands

| Command | Description |
|----------|-------------|
| `governant validate` | Validate resources against a policy (exits non‑zero on violations unless `--audit`). |
| `governant report` | Convert JSON results into HTML/Markdown/SARIF. |
| `governant fix` | Attempt best‑effort remediation via PRs. |
| `governant lint` | Lint/validate policy files against schema. |
| `governant version` | Print current version. |

**Global flags:** `--audit`, `--verbose`, `--provider`, `--org`, `--repo`, `--selector.file`

---

## 🧪 Examples

### Example: GitHub ruleset

```yaml
rules:
  github:
    branch_protection:
      required: true
      require_status_checks: true
      required_approvals: 2
      code_scanning_required: true
    environments:
      production:
        approvals_required: 2
        required_reviewers: ["release-managers"]
        restricted_deployers: ["platform-ci"]
```

### Example: ArgoCD app policy

```yaml
selector:
  provider: argocd
  project: platform
rules:
  argocd:
    syncPolicy: automated
    prune: true
    selfHeal: true
    allowEmpty: false
```

### Example: Terraform policy

```yaml
selector:
  provider: terraform
rules:
  terraform:
    minimum_version: "1.5.0"
    forbidden_providers: ["random"]
    required_providers:
      aws: ">= 5.0.0"
    tag_enforcement:
      required_tags: ["owner", "cost-center", "environment"]
```

---

## 🔌 Integrations

### GitHub Action (CI)

```yaml
name: Governance Validation
on:
  pull_request:
    branches: [main]
jobs:
  compliance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Governant Validate
        uses: governant-project/governant-action@v1
        with:
          policy: ./policies/production.yaml
          provider: github
          org: schroder-engineering
```

### Pre-commit

```yaml
repos:
  - repo: local
    hooks:
      - id: governant-lint
        name: Governant Policy Lint
        entry: governant lint --policy policies/production.yaml
        language: system
        files: ^policies/.*\.ya?ml$
```

---

## 🗂 Repository Structure

```
governant/
├── cli/                  # CLI core
├── engine/               # Policy engine
├── providers/            # github/, argocd/, terraform/
├── schemas/              # JSON Schemas for policies
├── reports/              # Output artifacts (gitignored)
├── examples/             # Example policies and rule packs
├── docs/                 # MkDocs site
├── .github/
│   └── workflows/ci.yml  # Lint + unit tests
├── pyproject.toml
├── CONTRIBUTING.md
├── CODE_OF_CONDUCT.md
└── LICENSE
```

---

## 🗺 Roadmap

| Phase | Focus | Key Deliverables |
|------:|-------|------------------|
| 1 — MVP | CLI + GitHub provider | Policy schema, basic validators, JSON/HTML reports |
| 2 — Expansion | Terraform + ArgoCD providers | Cross‑tool governance, selectors |
| 3 — Automation | Auto‑fix + GitHub Action | PR‑based remediation, SARIF export |
| 4 — Dashboard | Streamlit/React UI | Multi‑org view, metrics, trendlines |
| 5 — Enterprise | Vault/OIDC/Azure | Secretless auth, SSO, plugin system |

---

## 🤝 Contributing

We welcome contributions! Please read **CONTRIBUTING.md** for details on our code of conduct, the process for submitting pull requests, and how to run tests locally.

Quick start:
```bash
# clone
git clone https://github.com/governant-project/governant-cli.git
cd governant-cli

# create venv
python -m venv .venv && source .venv/bin/activate

# install dev deps
pip install -e ".[dev]"

# run tests
pytest -q
```

---

## 🛡 Security

If you discover a security issue, please **do not open a public issue**.  
Email the maintainers at **security@governant.io** with details and reproduction steps. We follow a **90‑day responsible disclosure** window when appropriate.

---

## 🔢 Versioning

We use **Semantic Versioning** (SemVer). Breaking changes bump the major version.  
Changelogs are maintained in **CHANGELOG.md**.

---

## 📘 License

MIT © 2025 [Erasmo Domínguez](https://github.com/erasmolpa)

---

## 💬 Credits & Inspiration

- Open Policy Agent (OPA) • HashiCorp Sentinel • GitHub Rulesets  
- ArgoCD App‑of‑Apps • Kubernetes RBAC • Policy‑as‑Code movement  
- The idea that **governance = trust through code**

> “Governance isn’t about restriction — it’s about **enabling autonomy with confidence**.”
