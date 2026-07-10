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

**Branch protection is enforced** via a repository ruleset (`protect-main`) on
`main` — the repo is public, which enables it (and gives unlimited Actions
minutes). The ruleset makes the gates *block* merges rather than only advise:

- **Require a PR before merging** (0 approvals — the sole owner cannot
  self-approve; L5 is the human's merge action plus the recorded
  `docs/audit/log.md` row, informed by the advisory L4 findings).
- **Required status checks** (strict — branch must be up to date):
  `L1-policy`, `L1-gitleaks`, `L1-terraform`, `L2-tests`, `L2-frontend-tests`,
  `L2-backend-image`, `L3-diff-guard`, `checks-selftest`.
- **`L4-ai-review` is intentionally NOT required.** It fails "forced-high" on
  any change outside `src/` and `tests/` by design — that is the L5 escalation
  signal, not a defect. Requiring it would make every docs/workflow/config PR
  permanently unmergeable. It stays advisory: a human reads its findings and
  merges (that is L5).
- Force-pushes to `main` and branch deletion are blocked. Repository admins
  have `always` bypass (anti-lockout).

**Audit-log push does not touch `main`.** The deploy step appends its L5 row to
a dedicated, unprotected `audit-log` orphan branch
(`scripts/record_deploy_approval.sh`), never to `main`. The ruleset targets the
default branch only, so the bot pushes with plain `contents: write` — no ruleset
bypass, and `main` protection stays absolute. The `main` copy of
`docs/audit/log.md` documents the format; live rows are on the `audit-log`
branch. (This resolves the earlier main-push conflict; nothing about the audit
record depends on the Azure bootstrap beyond the deploy jobs becoming active.)

To inspect or change the rule:
`gh api repos/liubrend/v20-azure-clean/rulesets` (list),
`gh api repos/liubrend/v20-azure-clean/rulesets/<id>` (detail).

## Supply-chain scanning

Layered on top of the homegrown L1 scanners, each on the cadence that fits it:

- **SCA (per-PR gate)** — `L1-dep-review` runs `dependency-review` on every PR and
  **fails** if the diff introduces a new `high`+ vulnerable dependency. It's cheap
  and only meaningful per-PR (it diffs base vs head), so it stays in `ci.yml`.
- **SCA (continuous)** — Dependabot (`.github/dependabot.yml`) opens weekly update
  PRs; Dependabot **alerts + automated security fixes** are enabled repo-wide.
- **SAST** — CodeQL (`.github/workflows/codeql.yml`) analyzes Java + TypeScript on
  PR, push, and weekly; results in the **Security** tab.
- **CVE sweep (nightly)** — `security-scan.yml` runs Trivy over the repo tree and
  the built `sample-service` image nightly (+ on push to `main` + on demand), **not
  on every PR**. CVEs are disclosed against unchanged code over time, so a nightly
  sweep catches more than per-PR runs and costs less CI. Trivy is installed as a
  **standalone binary** (signed apt repo) — no Docker for the fs scan, no
  version-pinned action; portable to any Debian-family CI.

**Advisory by design.** CodeQL and the Trivy sweep are **not** in the required-checks
ruleset — a base-image CVE or a finding in the current demo code would otherwise
block every PR (same reasoning as `L4-ai-review`). `dependency-review` runs as a
PR check but is also not required yet. **Promote to blocking** once the baseline is
triaged: flip Trivy's `--exit-code` to `1`, and add `L1-dep-review` and the two
`CodeQL / analyze (...)` contexts to the `protect-main` ruleset's required checks
(the nightly Trivy job is not a PR check, so it stays out of the required list).

## Gate trigger map

Where each L1–L5 layer fires. The **8 required** checks block a merge; everything
else runs and reports but does not block (the deliberate advisory tier).

| Layer | Gate | Where | When | Enforcement |
|---|---|---|---|---|
| **L1** | PreToolUse hook (`pretool_security_check.py`) | Local — Claude Code tool calls | Before each Bash/Write/Edit/NotebookEdit | Blocks the call (fail-closed) |
| **L1** | pre-commit hook (`security_precommit.py --staged`) | Local — git commit | On commit, **only if** `install_hooks.py` was run | Blocks commit — opt-in, not installed by default |
| **L1** | `L1-policy` (scanner + `forbid.sh` + `ai_sbom_check`) | CI | PR + push to `main` | **Required** |
| **L1** | `L1-gitleaks` (history secret scan) | CI | PR + push to `main` | **Required** |
| **L1** | `L1-terraform` (fmt + validate) | CI | PR + push to `main` | **Required** |
| **L1** | `checks-selftest` (prove the checks bite) | CI | PR + push to `main` | **Required** |
| **L1** | `L1-dep-review` (new-vuln-dep SCA gate) | CI | PR only | Advisory |
| **L1** | CodeQL (SAST) | CI (`codeql.yml`) | PR + push `main` + weekly | Advisory |
| **L1** | Trivy CVE sweep | CI (`security-scan.yml`) | Nightly + push `main` + on-demand | Advisory |
| **L1** | Dependabot alerts / update PRs | Repo-wide | Continuous alerts + weekly PRs | Advisory |
| **L2** | `L2-tests` (unit + Testcontainers integration) | CI | PR + push to `main` | **Required** |
| **L2** | `L2-frontend-tests` (Karma/Jasmine) | CI | PR + push to `main` | **Required** |
| **L2** | `L2-backend-image` (build + `/health` smoke) | CI | PR + push to `main` | **Required** |
| **L3** | `L3-diff-guard` (auth isolation, blast radius, order/risk combos) | CI | PR + push to `main` | **Required** |
| **L4** | `L4-ai-review` (LLM reviewer on the diff) | CI | PR + push to `main` (skips on push when the SHA came from a merged PR) | Advisory — forced-high signals L5 |
| **L5** | Require-PR + human merge | Ruleset `protect-main` | Every change to `main` | Blocks: no PR / not green → no merge |
| **L5** | Deploy approval (`rationale` + audit row) | Deploy → `audit-log` branch | On dispatch / push-main deploy | Records the decision (dormant until Azure) |

**Coverage caveat:** L2/L3/L4 are entirely CI-side, and the local L1 pre-commit
hook is opt-in (`install_hooks.py`) — so before CI, a plain `git commit` in a
terminal is guarded by nothing unless that hook is installed. The PreToolUse hook
covers only tool calls made *through* Claude Code, not a human typing `git commit`.
