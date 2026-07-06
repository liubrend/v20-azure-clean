# CLAUDE.md — standards for agents in this repo (L1)
> This file is the **L1 policy layer**: it defines "good" once so every agent — and the L4
> reviewer, and CI — applies the same rules. Edit the placeholders for each project.

## Repository
v20-azure-clean

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
| `docs/specs/spec-001.md` | First feature spec (one user-facing capability, with Given/When/Then scenarios) |
| `docs/stories/story-*.md` | Story breakdowns with acceptance criteria |
| `.project/config.yaml` | Project name, phase, team |
| `.project/stack.yaml` | Finalized stack and verified dev commands |
| `.project/plan.md` | Current feature plan and story status |

## Invariants (HARD rules - never violate)
- Never mix auth/credential changes with other changes in one PR.
- Secrets come from env — never hardcode keys, never log them.
- Any change to documentation or project structure outside `src/` and `tests/`
  (docs, `AGENTS.md`/`CLAUDE.md`, `.project/`, schemas, infra, CI/workflows,
  runbooks, etc.) is forced **HIGH** severity, regardless of how small or
  correct it looks. It requires a human-reviewed and human-approved PR. The L4
  reviewer may report findings but must never approve or merge it automatically.

## What requires human approval (L5)
Any change touching: auth/credentials, risk limits, anything the L4 reviewer marks
**high** severity, or any documentation/structure change outside `src/` and
`tests/` (forced **high** per the invariant above). These go through a PR and a
recorded human approval — never a direct push to `main`, and never an
automated-only review or approval.

## For agents working here
- Read the relevant `docs/specs/*.md` and this file before editing.
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
Java/Spring Boot microservices live in `backend/` (Gradle multi-module: `api-gateway`, `sample-service`). CI pins **Java 21** (Temurin); target that. RESTful APIs; Azure SQL via JPA + Liquibase; Azure Blob Storage via `BlobStorageService`.

- **Install/build**: `cd backend && ./gradlew build` (the committed wrapper pins Gradle 8.12; deps from Maven Central via the Spring Boot BOM).
- **Test**: `cd backend && ./gradlew test` — JUnit 5 + Mockito. **No DB/Docker needed**: unit tests mock the repository/blob store, controller slices use `@WebMvcTest`. The CI L2 gate runs exactly this.
- **Integration test**: `cd backend && ./gradlew :sample-service:integrationTest` — a separate source set that spins a throwaway **SQL Server** via Testcontainers, applies Liquibase, exercises the REST layer. **Needs a Docker daemon.**
- **Run**: `cd backend && ./gradlew :sample-service:bootRun` (boots without env for smoke; for real data set `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`, `BLOB_CONNECTION_STRING`, and `LIQUIBASE_ENABLED=true`). The gateway: `./gradlew :api-gateway:bootRun`.
- **Migrations**: Liquibase changelog at `backend/sample-service/src/main/resources/db/changelog/db.changelog-master.yaml`; runs on startup only when `LIQUIBASE_ENABLED=true`. Connection details come from env (Key Vault → Container Apps), never hardcoded.
- No JDK in this env by default; fetch a portable Temurin 21 tarball and set `JAVA_HOME` before running the wrapper.
