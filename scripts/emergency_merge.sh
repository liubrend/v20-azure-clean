#!/usr/bin/env bash
# BREAK-GLASS emergency merge. See runbooks/break-glass.md.
#
# Merges a PR with only L1 + L2 MANDATED; L3 / L4 / L5 are DEFERRED to a
# mandatory 48h post-hoc review. This is a loud, audited procedure — NOT a quiet
# bypass: every invocation opens a `break-glass-review` issue and appends a row
# to the audit-log branch, then admin-merges (the invoker's own ruleset bypass).
#
#   bash scripts/emergency_merge.sh --pr <N> --incident <ID> --reason "<why>"
#   bash scripts/emergency_merge.sh ... --dry-run   # verify setup, change nothing
#
# --dry-run runs the read-only checks (on-call membership, L1+L2 green) against a
# real PR and PRINTS the issue/audit-row/merge it WOULD do — but opens no issue,
# writes no audit row, and does not merge. Use it to test break-glass before you
# need it.
#
# Requires: an on-call admin (listed in .github/oncall.txt AND a repo admin, so
# `gh pr merge --admin` can override protection). gh + jq, authenticated.
set -euo pipefail
export MSYS_NO_PATHCONV=1

ONCALL_FILE=".github/oncall.txt"
AUDIT_BRANCH="audit-log"
SLA_HOURS=48
# L1 + L2 — must be green even in an emergency (never ship a secret or a broken
# build). L3-diff-guard and L4-ai-review are intentionally omitted (deferred).
MANDATORY_CHECKS="L1-policy L1-gitleaks L1-terraform L2-tests L2-frontend-tests L2-backend-image L2-spec-traceability checks-selftest"

# --- 1. Parse + validate args FIRST (no gh needed — keeps this offline-testable).
PR="" INCIDENT="" REASON="" DRY_RUN=false
while [ $# -gt 0 ]; do
  case "$1" in
    --pr) PR="${2:-}"; shift 2 || true;;
    --incident) INCIDENT="${2:-}"; shift 2 || true;;
    --reason) REASON="${2:-}"; shift 2 || true;;
    --dry-run) DRY_RUN=true; shift;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "emergency_merge: unknown arg '$1'" >&2; exit 2;;
  esac
done
if [ -z "$PR" ] || [ -z "$INCIDENT" ] || [ -z "$REASON" ]; then
  echo "usage: emergency_merge.sh --pr <N> --incident <ID> --reason \"<why>\"" >&2
  echo "  all three are REQUIRED — break-glass must be justified." >&2
  exit 2
fi

REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

# --- 2. Authorize: the invoker must be on the on-call roster.
ME="$(gh api user --jq .login)"
if [ ! -f "$ONCALL_FILE" ] || ! grep -qxF "$ME" "$ONCALL_FILE"; then
  echo "emergency_merge: REFUSED — '$ME' is not on the on-call roster ($ONCALL_FILE)." >&2
  exit 1
fi

# --- 3. L1 + L2 must be green on the PR (mandated even in an emergency).
SHA="$(gh pr view "$PR" --repo "$REPO" --json headRefOid -q .headRefOid)"
echo "break-glass: PR #$PR @ ${SHA:0:7} — verifying L1+L2 (L3/L4/L5 will be deferred)"
ROLLUP="$(gh pr checks "$PR" --repo "$REPO" --json name,state)"
for chk in $MANDATORY_CHECKS; do
  st="$(printf '%s' "$ROLLUP" | jq -r ".[]|select(.name==\"$chk\")|.state" | head -1)"
  if [ "$st" != "SUCCESS" ]; then
    echo "emergency_merge: REFUSED — mandatory L1/L2 check '$chk' is '${st:-missing}' (must be SUCCESS)." >&2
    exit 1
  fi
done
echo "break-glass: L1+L2 all green."

DATE_UTC="$(date -u +%Y-%m-%d)"
esc() { printf '%s' "$1" | tr '\n' ' ' | sed 's/|/\\|/g'; }
AUDIT_ROW="| $DATE_UTC | #$PR | \`${SHA:0:7}\` | $(esc "$INCIDENT") | EMERGENCY | $(esc "$ME") | Break-glass | L1+L2 only; L3/L4/L5 deferred | $(esc "$REASON") |"

if $DRY_RUN; then
  echo ""
  echo "=== DRY RUN — no issue opened, no audit row written, PR NOT merged ==="
  echo "on-call check : PASS ($ME on roster)"
  echo "L1+L2 check   : PASS (all mandatory checks green)"
  echo "would open    : issue 'break-glass review: PR #$PR ($INCIDENT)' [break-glass-review, ${SLA_HOURS}h SLA]"
  echo "would append  : $AUDIT_ROW"
  echo "would run     : gh pr merge $PR --merge --admin"
  echo "=== dry run OK — break-glass setup is functional ==="
  exit 0
fi

# --- 4. Open the mandatory post-hoc review issue (48h SLA).
ISSUE_URL="$(gh issue create --repo "$REPO" \
  --title "break-glass review: PR #$PR ($INCIDENT)" \
  --label "break-glass-review" \
  --body "Emergency merge of #$PR via break-glass — **L1+L2 only; L3/L4/L5 deferred**.

- Incident: $INCIDENT
- Reason: $REASON
- Invoked by: $ME
- Merged SHA: $SHA
- SLA: **review within ${SLA_HOURS}h.** Run the deferred L3/L4 review on this SHA,
  confirm the emergency was justified, and file any follow-up fix. Close when done.")"
echo "break-glass: review issue -> $ISSUE_URL"

# --- 5. Append a break-glass row to the audit-log branch (append-only ledger).
git fetch origin "$AUDIT_BRANCH" --quiet
WT="$(mktemp -d)"
git worktree add --quiet "$WT" "origin/$AUDIT_BRANCH"
printf '%s\n' "$AUDIT_ROW  (review: $ISSUE_URL)" >> "$WT/docs/audit/log.md"
git -C "$WT" add docs/audit/log.md
git -C "$WT" commit --quiet -m "audit: break-glass merge of PR #$PR ($INCIDENT)"
git -C "$WT" push --quiet origin "HEAD:$AUDIT_BRANCH"
git worktree remove --force "$WT"
echo "break-glass: audit-log row appended."

# --- 6. Admin-merge (uses the invoker's own ruleset bypass — no standing bot bypass).
gh pr merge "$PR" --repo "$REPO" --merge --admin
echo "break-glass: MERGED PR #$PR. Deferred review is MANDATORY within ${SLA_HOURS}h: $ISSUE_URL"
