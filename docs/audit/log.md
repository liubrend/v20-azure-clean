# Audit log (L5)

Human deploy approvals. Agents never self-approve (`.project/plan.md`, CLAUDE.md "L5").

> **Live rows live on the `audit-log` branch, not here.** `main` is protected by
> a ruleset that (correctly) rejects the deploy bot's direct push, so the ledger
> is maintained on a dedicated, unprotected orphan branch:
> [`docs/audit/log.md` on `audit-log`](../../../../tree/audit-log/docs/audit/log.md).
> This copy on `main` documents the format and header. Do not hand-edit either —
> git history is the tamper-evidence.

**How rows get there:** appended automatically by the deploy workflows
(`deploy-{backend,frontend}.yml`) after a successful, gates-passed deploy — the
gated deploy is the trigger, so this record cannot drift from what actually
shipped (`scripts/record_deploy_approval.sh` pushes to the `audit-log` branch).
The human supplies `rationale` (required) and `rollback_plan` (optional) via the
`workflow_dispatch` form; on a push-triggered deploy the rationale is derived
from the merged PR. Rows are appended at end-of-file; keep the table last.

**Scope:** this logs **deploys** to an environment. Forced-high PR approvals for
docs / workflow / source changes that never deploy are recorded by the GitHub PR
approval itself, not here — copying them in would just duplicate git history.

Columns — Date (UTC) · PR · Deployed SHA · Jira Key · Env · Approver · Decision ·
L4 verdict · Rationale / Rollback:

| Date (UTC) | PR | Deployed SHA | Jira Key | Env | Approver | Decision | L4 | Rationale / Rollback |
|---|---|---|---|---|---|---|---|---|
