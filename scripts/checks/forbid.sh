#!/usr/bin/env bash
# Fail-closed forbidden-pattern scanner.
#   exit 0 = clean   exit 1 = violation found   exit 2 = could-not-verify (FAIL CLOSED)
# Usage: forbid.sh <path> <key>   (key: market | secret)
#
# Lesson 0009 habits, made concrete:
#   - fail closed: missing path / missing grep / grep error => exit 2, never a silent pass
#   - don't swallow: grep's exit code is inspected explicitly (0 match / 1 no-match / >1 error)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"; . "$here/lib.sh"
path="${1:?usage: forbid.sh <path> <key>}"
key="${2:?usage: forbid.sh <path> <key>}"

case "$key" in
  market) regex="$MARKET_ORDER_RE"; label="market order (limit-only policy)";;
  secret) regex="$SECRET_RE";       label="hardcoded secret (use env vars)";;
  *) echo "forbid: unknown key '$key' — fail closed" >&2; exit 2;;
esac

command -v grep >/dev/null 2>&1 || { echo "forbid: grep not found — fail closed" >&2; exit 2; }
[ -e "$path" ] || { echo "forbid: path '$path' not found — fail closed (set CODE_ROOT?)" >&2; exit 2; }

rc=0; out="$(grep -rniE "$regex" "$path")" || rc=$?
case "$rc" in
  0) printf '%s\n' "$out" >&2; echo "VIOLATION: $label in $path" >&2; exit 1;;
  1) exit 0;;                       # grep: no match => clean
  *) echo "forbid: grep error (rc=$rc) — fail closed" >&2; exit 2;;
esac