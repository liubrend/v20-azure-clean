#!/usr/bin/env bash
# Append an L5 deploy-approval row to the audit ledger, then commit + push to
# the dedicated `audit-log` branch. Called by the deploy workflows AFTER a
# successful, gates-passed deploy: the gated deploy is the trigger, so the
# record cannot drift from what shipped. Git history is the tamper-evidence;
# the ledger is the human-readable register.
#
# Why a dedicated branch, not main: `main` is protected by the `protect-main`
# ruleset (require-PR + required checks), which would reject a bot's direct
# push. The ruleset targets the default branch only, so `audit-log` (an orphan
# branch holding just the ledger) is writable with plain contents:write — no
# ruleset bypass, so main protection stays absolute. Pushes to `audit-log`
# match no workflow trigger (ci.yml/deploy are main-only), so there is no loop.
#
# Required env: DEPLOY_ENV DEPLOY_SHA ACTOR EVENT_NAME REPO
# Optional env: RATIONALE ROLLBACK JIRA_KEY LOG_FILE AUDIT_BRANCH
#               RECORD_DRY_RUN=1  -> print the row and exit (no git); for selftest
set -euo pipefail

AUDIT_BRANCH="${AUDIT_BRANCH:-audit-log}"

LOG_FILE="${LOG_FILE:-docs/audit/log.md}"
: "${DEPLOY_ENV:?need DEPLOY_ENV}"
: "${DEPLOY_SHA:?need DEPLOY_SHA}"
: "${ACTOR:?need ACTOR}"
: "${EVENT_NAME:?need EVENT_NAME}"
: "${REPO:?need REPO}"

DATE_UTC="$(date -u +%Y-%m-%d)"
SHORT_SHA="${DEPLOY_SHA:0:7}"
RATIONALE="${RATIONALE:-}"
ROLLBACK="${ROLLBACK:-—}"
JIRA_KEY="${JIRA_KEY:-—}"
PR_REF="—"

# Derive rationale + PR link from the merged PR when the human did not supply one
# (i.e. a push-triggered deploy — the L5 record is the PR approval that merged it).
if [ -z "$RATIONALE" ] && [ "$EVENT_NAME" = "push" ] && command -v gh >/dev/null 2>&1; then
  PR_JSON="$(gh api "repos/$REPO/commits/$DEPLOY_SHA/pulls" \
    --jq '[.[] | select(.merged_at != null)][0] // empty' 2>/dev/null || true)"
  if [ -n "$PR_JSON" ]; then
    PR_NUM="$(printf '%s' "$PR_JSON" | jq -r '.number')"
    PR_TITLE="$(printf '%s' "$PR_JSON" | jq -r '.title')"
    RATIONALE="Auto-deploy on merge of PR #$PR_NUM: $PR_TITLE"
    PR_REF="#$PR_NUM"
  fi
fi
[ -z "$RATIONALE" ] && RATIONALE="(no rationale provided)"

esc() { printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\\|/g'; }
ROW="| $DATE_UTC | $PR_REF | \`$SHORT_SHA\` | $(esc "$JIRA_KEY") | $(esc "$DEPLOY_ENV") | $(esc "$ACTOR") | Approved | deploy-gated | $(esc "$RATIONALE") — rollback: $(esc "$ROLLBACK") |"

if [ "${RECORD_DRY_RUN:-}" = "1" ]; then
  printf '%s\n' "$ROW"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Discard any working-tree changes the deploy made to tracked files (e.g. the
# frontend bakes the API URL into environment.prod.ts) so the branch switch is
# clean and only the audit-log append gets committed.
git reset --hard HEAD --quiet 2>/dev/null || true

# Re-apply the row onto a fresh origin/<audit-branch> each attempt so a
# concurrent deploy's append never conflicts (we only ever add one line at EOF).
for attempt in 1 2 3 4 5; do
  git fetch origin "$AUDIT_BRANCH" --quiet
  # -f: switching from the full main tree to the orphan ledger branch; force a
  # clean switch (working tree was already reset above).
  git checkout -f -B "$AUDIT_BRANCH" "origin/$AUDIT_BRANCH" --quiet
  printf '%s\n' "$ROW" >> "$LOG_FILE"
  git add "$LOG_FILE"
  git commit -m "audit: record $DEPLOY_ENV deploy of $SHORT_SHA" --quiet
  if git push origin "$AUDIT_BRANCH" --quiet 2>/dev/null; then
    echo "audit row recorded for $SHORT_SHA on branch $AUDIT_BRANCH"
    exit 0
  fi
  echo "push race on attempt $attempt — retrying" >&2
  git reset --hard "origin/$AUDIT_BRANCH" --quiet 2>/dev/null || true
  sleep "$((attempt * 2))"
done

echo "::error::deploy SUCCEEDED but the audit row could not be pushed to $AUDIT_BRANCH — add it by hand" >&2
exit 1
