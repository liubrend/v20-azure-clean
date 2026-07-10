#!/usr/bin/env bash
# Stand up the repo-level governance settings that do NOT travel with a clone/
# fork. The committed files (workflows, scripts, dependabot.yml) come along with
# the code, but rulesets, Dependabot alerts, secret scanning, and repo flags are
# GitHub settings that a copy does not inherit — so re-run this once per repo.
#
#   gh auth login          # needs admin on the target repo
#   bash scripts/bootstrap_repo.sh [owner/repo]   # defaults to the current repo
#
# Idempotent: safe to re-run. Rulesets are created only if a ruleset of the same
# name does not already exist. This does NOT change repo visibility (branch
# protection needs a public repo or a paid plan — set that yourself), and it can
# NOT set the required secrets (printed as manual reminders at the end).
#
# Requires: gh (authenticated), jq.
set -euo pipefail

# Stop Git Bash (Windows) from rewriting the gh api "repos/..." paths into
# filesystem paths. No-op on Linux/macOS.
export MSYS_NO_PATHCONV=1

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
echo "Bootstrapping repo settings for: $REPO"
api() { GH_REPO="" gh api "$@"; }

# --- 1. Secret scanning + push protection (blocks secrets at push time) --------
echo "-> secret scanning + push protection"
api -X PATCH "repos/$REPO" --input - >/dev/null <<'JSON'
{ "security_and_analysis": {
    "secret_scanning": { "status": "enabled" },
    "secret_scanning_push_protection": { "status": "enabled" } } }
JSON

# --- 2. Dependency graph + Dependabot alerts (powers L1-dep-review) -------------
echo "-> Dependabot vulnerability alerts (dependency graph)"
api -X PUT "repos/$REPO/vulnerability-alerts" >/dev/null
# Dependabot security-update PRs are intentionally left OFF for the demo scaffold
# (see .github/dependabot.yml). Enable when real deps land:
#   gh api -X PUT "repos/$REPO/automated-security-fixes"

# --- 3. Auto-delete merged head branches ---------------------------------------
echo "-> delete_branch_on_merge"
api -X PATCH "repos/$REPO" -F delete_branch_on_merge=true >/dev/null

# --- 4. Rulesets (branch protection) -------------------------------------------
# These require a public repo or a paid plan; if creation 403s, that's why.
existing_ruleset() { api "repos/$REPO/rulesets" --jq ".[]|select(.name==\"$1\")|.name" 2>/dev/null; }

create_ruleset() {
  local name="$1" json="$2"
  if [ -n "$(existing_ruleset "$name")" ]; then
    echo "-> ruleset '$name' already exists — skipping"
  else
    echo "-> creating ruleset '$name'"
    printf '%s' "$json" | api -X POST "repos/$REPO/rulesets" --input - >/dev/null
  fi
}

# protect-main: require a PR + the 8 objective gate checks (strict), block force
# push / deletion. L4-ai-review is deliberately NOT required (advisory). Admin
# bypass = anti-lockout. required_approving_review_count 0 so a sole owner (who
# cannot self-approve) is not locked out.
create_ruleset "protect-main" '{
  "name": "protect-main", "target": "branch", "enforcement": "active",
  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "rules": [
    { "type": "pull_request", "parameters": {
        "required_approving_review_count": 0, "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false, "require_last_push_approval": false,
        "required_review_thread_resolution": false } },
    { "type": "required_status_checks", "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "L1-policy" }, { "context": "L1-gitleaks" },
          { "context": "L1-terraform" }, { "context": "L2-tests" },
          { "context": "L2-frontend-tests" }, { "context": "L2-backend-image" },
          { "context": "L3-diff-guard" }, { "context": "checks-selftest" } ] } },
    { "type": "non_fast_forward" }, { "type": "deletion" }
  ] }'

# protect-audit-log: the deploy-appended ledger branch is append-only — block
# deletion and force-push, but allow fast-forward appends (no PR/checks rules).
create_ruleset "protect-audit-log" '{
  "name": "protect-audit-log", "target": "branch", "enforcement": "active",
  "conditions": { "ref_name": { "include": ["refs/heads/audit-log"], "exclude": [] } },
  "bypass_actors": [ { "actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always" } ],
  "rules": [ { "type": "deletion" }, { "type": "non_fast_forward" } ] }'

# --- 5. Manual reminders (things this script cannot do for you) -----------------
cat <<'NOTE'

Done. Manual follow-ups this script cannot do:
  * Repo VISIBILITY: rulesets need a public repo or a paid plan. Set it yourself.
  * SECRETS/VARS (not stored in code):
      gh secret set ANTHROPIC_API_KEY            # L4 AI review
      gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN   # frontend deploy
      gh variable set AZURE_CLIENT_ID ...        # + the other AZURE_*/ACR_*/APP vars (Terraform bootstrap)
  * The `audit-log` orphan branch: created on first deploy by
    scripts/record_deploy_approval.sh; the protect-audit-log ruleset above
    guards it once it exists.
  * Local hooks per clone: run `make setup`.
NOTE
