# runbook — Break-glass emergency merge

- **Service:** any (governance procedure)
- **Owner:** on-call (see `.github/oncall.txt`)
- **Last verified:** 2026-07-10

Break-glass is a **loud, audited** way to ship a fix during a live incident when
the normal L1–L5 flow is too slow. It is **not** a backdoor: it mandates the
automated safety floor, defers only the judgment/process gates, and forces a
post-hoc review. If you find yourself reaching for it often, the signal is that
the *normal* path is too slow — fix that, don't widen this.

## When to use this

A production incident that is actively bleeding (down / losing money / data at
risk) **and** the fix cannot wait for human review + L3/L4. Not for
convenience, not to dodge a red L4, not to skip a review you'd rather not get.

## What it does / does not do

| Layer | Break-glass |
|---|---|
| **L1** (secrets, policy, gitleaks, SBOM, tf-validate) | **Mandatory** — must be green |
| **L2** (unit + integration + image smoke + spec-traceability) | **Mandatory** — must be green |
| **L3** (diff-guard) | **Deferred** to the review issue |
| **L4** (AI review) | **Deferred** to the review issue |
| **L5** (human PR approval) | **Deferred** — the merge is the on-call admin's call, reviewed after |

The fix still ships through a PR whose CI has run; break-glass only overrides the
*require-review + L3 + remaining-checks* gate via the on-call admin's own bypass.
A fix that leaks a secret or doesn't build is still blocked — L1+L2 are never
skipped.

## Preconditions

- You are on the **on-call roster** (`.github/oncall.txt`) **and** a repo admin
  (so `gh pr merge --admin` can override protection).
- `gh` is authenticated; `jq` available.
- A **PR exists** for the fix (create the branch + PR as normal) and its **L1+L2
  checks are green**. You do not wait for L3/L4.
- You have an **incident ID** and a one-line **justification**.

## Steps

1. Open the fix as a normal PR; let CI run. Confirm the L1 + L2 checks are green.
2. Invoke break-glass:

   ```bash
   bash scripts/emergency_merge.sh --pr <N> --incident <ID> --reason "<why>"
   ```

   The script refuses if: you are not on-call, any L1/L2 check is not green, or a
   required arg is missing. On success it (a) opens a `break-glass-review` issue
   (48h SLA), (b) appends an `EMERGENCY` row to the `audit-log` branch, then
   (c) `gh pr merge --admin` merges the PR.
3. Verify the fix resolved the incident.

## Rollback

Break-glass is a merge, not a deploy. To undo: revert the merge (`gh pr create`
a revert, or another break-glass if still bleeding) and note it on the review
issue.

## Mandatory post-hoc review (the deal)

Every invocation opens a **`break-glass-review`** issue with a **48h SLA**. Within
48h, on-call must: run the deferred **L3/L4** review on the merged SHA, confirm
the emergency was justified, file any follow-up fix, and **close the issue**.
`break-glass-sla.yml` runs daily and **fails** (red run = the alert) if any such
issue is open past 48h. (Email/Slack notification is a TODO — channel TBD.)

## Maintaining the on-call set

- **Today (personal repo):** on-call = the usernames in `.github/oncall.txt`.
  Add/remove via a normal PR (forced-high → reviewed). The invoker must *also* be
  a repo admin for the `--admin` merge to work, so on-call ⊆ admins.
- **If moved to an org (recommended for a real team):** create a GitHub `oncall`
  team, add it as a bypass actor on the `protect-main` ruleset, and maintain
  on-call as team membership — decoupling "can break-glass" from "is admin."

## Escalation / caution

- **No path is off-limits** by policy (per decision) — but changing the guardrail
  stack itself (`security/`, `scripts/checks/`, workflows) via break-glass is
  especially high-risk; do it only if the incident truly requires it, and call it
  out explicitly on the review issue.
- Track **frequency**: repeated break-glass use is an incident in itself — the
  normal process is too slow. Review the audit-log `EMERGENCY` rows periodically.

## Related

- `scripts/emergency_merge.sh`, `.github/oncall.txt`, `.github/workflows/break-glass-sla.yml`
- The `audit-log` branch (permanent `EMERGENCY` record); README "Gate enforcement".
