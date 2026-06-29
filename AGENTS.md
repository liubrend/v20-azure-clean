# CLAUDE.md — standards for agents in this repo (L1)
> This file is the **L1 policy layer**: it defines "good" once so every agent — and the L4
> reviewer, and CI — applies the same rules. Edit the placeholders for each project.

## Repository
v19-GCP-clean-teamsEnabled

## docs
- domain language lives in `CONTEXT.md`
- technology framework and tools in `.project/stack.yaml`
- architecture in `docs/product/architecture.md`
- decisions in `docs/adr/`
- build order in `.project/plan.md`
**Keep these consistent with each other**

### Docs to Create as the Project Grows
| File | Content |
|---|---|
| `docs/product/prd.md` | Product requirements and user journeys |
| `docs/product/architecture.md` | System architecture and data flow |
| `docs/features/spec-001.md` | First feature spec (one user-facing capability, with Given/When/Then scenarios) |
| `docs/stories/story-*.md` | Story breakdowns with acceptance criteria |
| `.project/config.yaml` | Project name, phase, team |
| `.project/stack.yaml` | Finalized stack and verified dev commands |
| `.project/plan.md` | Current feature plan and story status |

## Invariants (HARD rules - never violate)
- Never mix auth/credential changes with other changes in one PR.
- Secrets come from env — never hardcode keys, never log them.

## What requires human approval (L5)
Any change touching: auth/credentials, risk limits, or anything the L4 reviewer marks **high** severity. These go through a PR and a recorded approval — never a direct push to `main`.

## For agents working here
- Read the relevant `docs/features/*.md` and this file before editing.
- Make the smallest change that satisfies the spec.
- If a invariant blocks the task, **stop and ask** — do not work around it.

## Smart Cavemen Protocol: Always response like smart cavemen. Cut all filter, keep all technique substance. 
- drop articals(a, an, the), filler(just, really, basically, actually). 
- drop pleasantries( sure, cerntainly, happy to). 
- no hdeging. Fragements fine. short synonyms. 
- Tehnical term stay exact. Code blocks unchanged.
- Pattern: [thing] [action] [reason]. [next step].

## Subagents and parallel
Always spawn a sub-agent for each service and run them in parallel if possible.

## Build / test / run (backend)
Python/FastAPI backend lives in `src/backend`; data layer lives in `src/data`. CI pins **Python 3.12**; target that.

- **Install**: `python -m venv .venv && .venv/bin/pip install -r requirements.txt && .venv/bin/pip install -e .`
  `requirements.txt` is the single source of deps (CI installs it; `pyproject.toml` reads it via dynamic deps).
- **Test**: `.venv/bin/pytest` (config in `pyproject.toml`: `pythonpath=["src"]`, coverage gate is CI's `--cov=src --cov-fail-under=90`).
  **Tests need a Docker daemon** — `tests/conftest.py` starts a throwaway `postgres:16-alpine` via testcontainers, migrates it with Alembic, truncates between tests. **No live Cloud SQL needed.**
- **Run**: set `DATABASE_URL` (e.g. `postgresql://user:pw@host:5432/db`), then `.venv/bin/alembic upgrade head` and `.venv/bin/uvicorn backend.main:app --reload`.
- **Migrations**: live in `src/data/migrations`; `alembic.ini` reads `DATABASE_URL` from env (`migrations/env.py`), never hardcoded. New revision: `.venv/bin/alembic revision -m "msg"`.
- **Lint**: `.venv/bin/ruff check .` (config in `pyproject.toml`; pre-existing `scripts/` excluded).
- No system pip in this env; bootstrap with `uv` (`curl -LsSf https://astral.sh/uv/install.sh | sh`, then `uv venv --python 3.12 .venv && uv pip install -r requirements.txt`).
