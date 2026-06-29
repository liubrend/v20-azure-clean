# v19-claudeTeamCCEY

[![CI](https://github.com/liubrend/v19-GCP-clean-teamsEnabled/actions/workflows/ci.yml/badge.svg)](https://github.com/liubrend/v19-GCP-clean-teamsEnabled/actions/workflows/ci.yml)

Project template bootstrapped from the [v17-hub](https://github.com/liubrend/v17-hub)
setup: an **agentic-SDLC** scaffold with an L1–L5 governance framework, CI/CD,
git hooks, security checks, and GCP infra — application code excluded.

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
| `infra/` | `terraform/` (GCP foundation + WIF) and `k8s/` (GKE manifests) |
| `Dockerfile`, `pyproject.toml`, `requirements.txt`, `alembic.ini` | backend build/runtime |

## Getting started

1. Fill the placeholders: project ids in `firebase.json` / `.firebaserc`, and
   `infra/terraform/terraform.tfvars` (copy from `.example`).
2. Add application code under `src/` and tests under `tests/` (see `AGENTS.md`).
3. Define the domain in `CONTEXT.md` and write the first spec in `docs/features/`.
4. Bootstrap WIF and set the GitHub repo variables/secrets so the CI gates and
   deploy workflows activate (see `infra/terraform/README.md`).

## The workflow

Plan → Develop → Test → Review (L4 reviewer subagent) → Deploy (human-approved,
recorded in `docs/audit/log.md`). See `.project/plan.md` and `AGENTS.md`.
