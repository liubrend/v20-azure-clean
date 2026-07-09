#!/usr/bin/env bash
# L3 diff heuristics as a testable check (selftest.sh feeds it fixtures).
# Reads changed paths, one per line, on stdin.
#   exit 0 = clean   exit 1 = violation   exit 2 = could-not-verify (fail closed)
#
# Rules (CLAUDE.md invariants):
#   - auth/credential changes must not mix with ANY other change in one PR
#   - order_engine must not mix with risk-limit changes
#   - more than MAX_FILES files => warning only (extra L5 scrutiny)
#
# Auth detection: a path is auth-flavored when a segment or token starts with
# an auth-ish term (auth, authn, authz, oauth, credential(s), creds, login,
# jwt, sso). Paths containing "author" are excluded wholesale -- name
# authorization code "authz", not "authorization", or the guard misses it.
set -euo pipefail

MAX_FILES="${MAX_FILES:-25}"

AUTH_INCLUDE_RE='(^|/|[-_.])(oauth|auth[nz]?|credentials?|creds|login|jwt|sso)'
AUTH_EXCLUDE_RE='author'

changed="$(cat || true)"
changed="$(printf '%s\n' "$changed" | sed '/^[[:space:]]*$/d')"
if [ -z "$changed" ]; then
  echo "diff-guard: no changed files"
  exit 0
fi

count=$(printf '%s\n' "$changed" | wc -l)
echo "diff-guard: $count file(s) changed"
if [ "$count" -gt "$MAX_FILES" ]; then
  echo "::warning::large change ($count files) — extra L5 scrutiny"
fi

auth_files="" ; other_files=""
while IFS= read -r path; do
  if printf '%s' "$path" | grep -qiE "$AUTH_INCLUDE_RE" \
     && ! printf '%s' "$path" | grep -qiE "$AUTH_EXCLUDE_RE"; then
    auth_files="$auth_files$path"$'\n'
  else
    other_files="$other_files$path"$'\n'
  fi
done <<EOF
$changed
EOF

if [ -n "$auth_files" ] && [ -n "$other_files" ]; then
  printf 'auth-flavored:\n%s' "$auth_files" >&2
  printf 'mixed with:\n%s' "$other_files" >&2
  echo "::error::auth/credential changes mixed with other changes in one PR — split it (CLAUDE.md invariant)"
  exit 1
fi

if printf '%s\n' "$changed" | grep -q "order_engine" \
   && printf '%s\n' "$changed" | grep -qE "risk[_-]?limit"; then
  echo "::error::order logic + risk-limit change in one PR — split it (CLAUDE.md)"
  exit 1
fi

echo "diff-guard: clean"
exit 0
