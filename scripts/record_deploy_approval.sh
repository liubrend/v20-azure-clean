#!/usr/bin/env bash
# Append an L5 deploy-approval row to docs/audit/log.md, then commit + push to
# main. Called by the deploy workflows AFTER a successful, gates-passed deploy:
# the gated deploy is the trigger, so the record cannot drift from what shipped.
# Git history is the tamper-evidence; this file is the human-readable register.
#
# Machine fills date/SHA/env/approver/PR; the human supplies rationale (required
# on workflow_dispatch) and rollback_plan via the dispatch form. On a push
# deploy the rationale is derived from the merged PR.
#
# Required env: DEPLOY_ENV DEPLOY_SHA ACTOR EVENT_NAME REPO
# Optional env: RATIONALE ROLLBACK JIRA_KEY LOG_FILE
#               RECORD_DRY_RUN=1  -> print the row and exit (no git); for selftest
#
# The commit is tagged [skip ci]: it must not re-trigger the gate workflow (the
# automatic GITHUB_TOKEN already suppresses that, this is belt-and-suspenders),
# and it never matches the deploy path filters, so there is no deploy loop.
set -euo pipefail

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

# Re-apply the row onto a fresh origin/main each attempt so a concurrent deploy's
# append never conflicts (we only ever add one line at end-of-file).
for attempt in 1 2 3 4 5; do
  git fetch origin main --quiet
  git checkout -B main origin/main --quiet
  printf '%s\n' "$ROW" >> "$LOG_FILE"
  git add "$LOG_FILE"
  git commit -m "audit: record $DEPLOY_ENV deploy of $SHORT_SHA [skip ci]" --quiet
  if git push origin main --quiet 2>/dev/null; then
    echo "audit row recorded for $SHORT_SHA"
    exit 0
  fi
  echo "push race on attempt $attempt — retrying" >&2
  git reset --hard "origin/main" --quiet 2>/dev/null || true
  sleep "$((attempt * 2))"
done

echo "::error::deploy SUCCEEDED but the audit row could not be pushed — add it to $LOG_FILE by hand" >&2
exit 1
