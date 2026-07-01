# v20-Azure-clean-teamsEnabled

[![CI](https://github.com/liubrend/v20-Azure-clean-teamsEnabled/actions/workflows/ci.yml/badge.svg)](https://github.com/liubrend/v20-Azure-clean-teamsEnabled/actions/workflows/ci.yml)

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
| `docs/` | `product/` (prd, architecture), `features/` (specs), `adr/`, `context/`, `audit/` |
| `.github/workflows/` | `ci.yml` (L1–L4 gates, on PR) + `deploy-{backend,frontend}.yml` |
| `.githooks/` + `scripts/` | pre-commit security scan and shared fail-closed checks |
| `security/` | `security_rules.json` consumed by the pre-commit scanner |
| `infra/terraform/` | Azure foundation (ACR, Container Apps, Azure SQL, Blob, Key Vault, OIDC) |
| `backend/` | Gradle multi-module Spring Boot services + their Dockerfiles |
| `src/frontend/` | Angular workspace (Karma/Jasmine, Static Web Apps config) |

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

1. Fill the placeholders: `infra/terraform/terraform.tfvars` (copy from `.example`;
   set `subscription_id`, `location`).
2. Build/test: `cd backend && ./gradlew test`; `npm --prefix src/frontend ci && npm --prefix src/frontend test`.
3. Define the domain in `CONTEXT.md` and write the first spec in `docs/features/`.
4. Bootstrap Azure + GitHub OIDC and set the repo variables/secrets so the CI gates and
   deploy workflows activate (see `infra/terraform/README.md`).

## Local development

**Backend** (Java 21 + the committed Gradle wrapper):

```bash
cd backend
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
