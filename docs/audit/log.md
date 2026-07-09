# Audit log (L5)

Human deploy approvals. Agents never self-approve (`.project/plan.md`, CLAUDE.md "L5").

**How rows get here:** appended automatically by the deploy workflows
(`deploy-{backend,frontend}.yml`) after a successful, gates-passed deploy — the
gated deploy is the trigger, so this record cannot drift from what actually
shipped (`scripts/record_deploy_approval.sh`). The human supplies `rationale`
(required) and `rollback_plan` (optional) via the `workflow_dispatch` form; on a
push-triggered deploy the rationale is derived from the merged PR. Git history is
the tamper-evidence — **do not hand-edit rows**, and keep the table the **last
content in this file** (rows are appended at end-of-file).

**Scope:** this logs **deploys** to an environment. Forced-high PR approvals for
docs / workflow / source changes that never deploy are recorded by the GitHub PR
approval itself, not here — copying them in would just duplicate git history.

Columns — Date (UTC) · PR · Deployed SHA · Jira Key · Env · Approver · Decision ·
L4 verdict · Rationale / Rollback:

| Date (UTC) | PR | Deployed SHA | Jira Key | Env | Approver | Decision | L4 | Rationale / Rollback |
|---|---|---|---|---|---|---|---|---|
