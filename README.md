# v20-azure-clean

[![CI](https://github.com/liubrend/v20-azure-clean/actions/workflows/ci.yml/badge.svg)](https://github.com/liubrend/v20-azure-clean/actions/workflows/ci.yml)

Project template bootstrapped from the [v17-hub](https://github.com/liubrend/v17-hub)
setup: an **agentic-SDLC** scaffold with an L1–L5 governance framework, CI/CD,
git hooks, security checks, and **Azure** infra. The application slice is a
**Java/Spring Boot** microservice backend (api-gateway + sample-service) and an
**Angular** frontend.

## Stack

- **Cloud**: Azure — Container Apps, Container Registry (ACR), Azure SQL Database,
  Blob Storage, Key Vault; GitHub OIDC (keyless CI).
- **Backend**: Java 21 / Spring Boot 3.4, Gradle (Kotlin DSL), microservices, RESTful
  APIs, JPA + Liquibase (Azure SQL), Azure Blob Storage. Tests: JUnit 5 + Mockito.
- **Frontend**: Angular 19, hosted on Azure Static Web Apps. Tests: Karma + Jasmine.

## Layout

| Path | What |
|---|---|
| `AGENTS.md` / `CLAUDE.md` | L1 policy: standards every agent, the L4 reviewer, and CI apply |
| `.project/` | Machine-readable metadata: `config.yaml`, `stack.yaml`, `plan.md` |
| `CONTEXT.md` | Domain glossary (ubiquitous language) — fill in per project |
| `docs/` | `product/` (prd, architecture), `specs/`, `adr/`, `context/`, `audit/`, `security/` (security intents), `data-model/` |
| `.github/workflows/` | `ci.yml` (L1–L4 gates, on PR) + `deploy-{backend,frontend}.yml` |
| `.githooks/` + `scripts/` | pre-commit security scan and shared fail-closed checks |
| `security/` | `security_rules.json` consumed by the pre-commit scanner |
| `infra/terraform/` | Azure foundation (ACR, Container Apps, Azure SQL, Blob, Key Vault, OIDC) |
| `src/backend/` | Gradle multi-module Spring Boot services + their Dockerfiles |
| `src/frontend/` | Angular workspace (Karma/Jasmine, Static Web Apps config) |
| `tests/` | `unit/` and `integration/` cross-cutting test suites |
| `migrations/` | Archival SQL from the old DB backup (never executed by the app; runtime schema is Liquibase in `backend/`) |

## Architecture

```
                 ┌──────────────────────────┐
  Browser ─────► │  Azure Static Web Apps    │   Angular 19 SPA
                 │  (Angular bundle)         │
                 └───────────┬──────────────┘
                             │  /api/**  (HTTPS)
                 ┌───────────▼──────────────┐
                 │  api-gateway             │   Spring Cloud Gateway  (:8080, public)
                 │  routes + CORS           │
                 └───────────┬──────────────┘
                             │  StripPrefix → /items
                 ┌───────────▼──────────────┐      ┌───────────────────┐
                 │  sample-service          │────► │  Azure SQL DB     │  (JPA + Liquibase)
                 │  REST API (:8081, internal)     └───────────────────┘
                 │  items CRUD + attachments│      ┌───────────────────┐
                 │                          │────► │  Azure Blob Storage│  (attachments)
                 └──────────────────────────┘      └───────────────────┘

  Runtime: Azure Container Apps · Images: ACR · Secrets: Key Vault · CI auth: GitHub OIDC
```

## REST API

Served by `sample-service` (reached through the gateway at `/api/...`):

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Liveness probe → `{"status":"ok"}` |
| `GET` | `/` | Service identity |
| `GET` | `/items` | List items |
| `GET` | `/items/{id}` | Get one item (404 if missing) |
| `POST` | `/items` | Create item (`{name, description}`) → 201 |
| `PUT` | `/items/{id}` | Update item |
| `DELETE` | `/items/{id}` | Delete item (+ its blob attachment) |
| `POST` | `/items/{id}/attachment` | Upload an attachment to Blob Storage (multipart `file`) |

## Getting started

1. Install the local git hooks: `python scripts/install_hooks.py` (sets
   `core.hooksPath` to `.githooks`, so the L1 security scan
   (`scripts/security_precommit.py`) runs on every commit, not just in CI).
2. Fill the placeholders: `infra/terraform/terraform.tfvars` (copy from `.example`;
   set `subscription_id`, `location`).
3. Build/test: `cd src/backend && ./gradlew test`; `npm --prefix src/frontend ci && npm --prefix src/frontend test`.
4. Define the domain in `CONTEXT.md` and write the first spec in `docs/specs/`.
5. Bootstrap Azure + GitHub OIDC and set the repo variables/secrets so the CI gates and
   deploy workflows activate (see `infra/terraform/README.md`).

Note: this repo does **not** run `install_hooks.py` automatically — a fresh
clone has no local hook until step 1 is run. Without it, the L1 security scan
only happens in CI (`ci.yml`), not before you commit.

## Local development

**Backend** (Java 21 + the committed Gradle wrapper):

```bash
cd src/backend
./gradlew test                              # unit tests — JUnit 5 + Mockito, no DB
./gradlew :sample-service:integrationTest   # Testcontainers SQL Server (needs Docker)
./gradlew :sample-service:bootRun           # domain service on :8081
./gradlew :api-gateway:bootRun              # gateway on :8080
```

For real data, set `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`,
`BLOB_CONNECTION_STRING`, and `LIQUIBASE_ENABLED=true` before `bootRun`.

**Frontend** (Angular + Karma/Jasmine, needs Chrome):

```bash
npm --prefix src/frontend ci
npm --prefix src/frontend start   # ng serve → http://localhost:4200
npm --prefix src/frontend test    # Karma ChromeHeadless
npm --prefix src/frontend run build
```

**Infra** (Terraform, validate only — no live apply needed):

```bash
cd infra/terraform && terraform init -backend=false && terraform validate
```

## The workflow

Plan → Develop → Test → Review (L4 reviewer subagent) → Deploy (human-approved,
recorded in `docs/audit/log.md`). See `.project/plan.md` and `AGENTS.md`.

## Gate enforcement & branch protection

The `agentic-sdlc-gates` workflow (L1–L4) runs on every PR **and** on push to
`main`. Deploys are additionally gated: `deploy-{backend,frontend}.yml` refuse
to ship unless that workflow succeeded on the exact pushed SHA (fail-closed).

**Known gap — the gates are not yet *required* checks.** Making CI a true merge
blocker needs a branch-protection rule on `main`, which GitHub only allows on a
**private repo under a paid plan** (Pro/Team/Enterprise) or on a **public repo**.
This repo is private on a free plan, so a PR can currently be merged while its
checks are still pending or failing (this has happened). Until that is resolved,
**the deploy-time gate is the enforcement backstop** — unverified code can land
on `main`, but it cannot deploy.

Decision required (pick one), then the required-status-checks rule can be applied
via `gh api repos/liubrend/v20-azure-clean/branches/main/protection`:

- **Upgrade to GitHub Pro** — keeps the repo private; enables branch protection.
- **Make the repo public** — free; exposes all code, history, and CI config.
- **Stay as-is** — deploy-time gate remains the only enforcement; accept that
  `main` can receive unverified merges.

Required checks to enforce once enabled: `L1-policy`, `L1-gitleaks`,
`L1-terraform`, `L2-tests`, `L2-frontend-tests`, `L2-backend-image`,
`L3-diff-guard`, `L4-ai-review`, `checks-selftest`. L5 (human approval) maps to
the "require a pull-request review before merge" branch-protection setting.
