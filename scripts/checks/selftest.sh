#!/usr/bin/env bash
# Prove shared checks both bite known-bad fixtures and pass clean fixtures.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass_count=0

expect_pass() {
  local label="$1"
  shift
  if "$@"; then
    pass_count=$((pass_count + 1))
  else
    echo "selftest: expected pass failed: $label" >&2
    return 1
  fi
}

expect_fail() {
  local label="$1"
  shift
  local rc=0
  "$@" >/dev/null 2>&1 || rc=$?
  if [ "$rc" -eq 1 ]; then
    pass_count=$((pass_count + 1))
  else
    echo "selftest: expected violation failed: $label (rc=$rc)" >&2
    return 1
  fi
}

mkdir -p "$tmp/clean" "$tmp/secret-bad" "$tmp/market-bad" "$tmp/scanner-bad-java" "$tmp/scanner-bad-tf" "$tmp/scanner-clean-java"

cat > "$tmp/clean/app.py" <<'EOF'
import os

API_KEY = os.environ["API_KEY"]
order_type = "limit"
EOF

# Assembled via printf so this script itself never contains a matchable
# key = "value" assignment (the scanner scans this file too).
printf 'API_KEY = "%s"\n' "hardcoded-demo-secret" > "$tmp/secret-bad/app.py"

cat > "$tmp/market-bad/app.py" <<'EOF'
order_type = "market"
EOF

expect_pass "clean secret scan" bash "$here/forbid.sh" "$tmp/clean" secret
expect_fail "hardcoded secret scan" bash "$here/forbid.sh" "$tmp/secret-bad" secret
expect_pass "clean market scan" bash "$here/forbid.sh" "$tmp/clean" market
expect_fail "market order scan" bash "$here/forbid.sh" "$tmp/market-bad" market

# --- security_precommit.py (the pre-commit / CI L1 scanner) must BITE too ---
# Regression guard for the blind spot where non-Python extensions (.java, .tf)
# were silently skipped: a skipped file exits 0 and these expect_fail cases catch it.
scanner="$here/../security_precommit.py"

printf 'public class Config { static final String API_KEY = "%s"; }\n' \
  "fixture0bad0secret0abcdef" > "$tmp/scanner-bad-java/Config.java"
printf 'password = "%s"\n' "fixture0bad0secret0abcdef" > "$tmp/scanner-bad-tf/main.tf"

cat > "$tmp/scanner-clean-java/Config.java" <<'EOF'
public class Config {
    static final String API_KEY = System.getenv("API_KEY");
}
EOF

expect_fail "scanner bites hardcoded secret in .java" \
  python3 "$scanner" "$tmp/scanner-bad-java/Config.java"
expect_fail "scanner bites hardcoded secret in .tf" \
  python3 "$scanner" "$tmp/scanner-bad-tf/main.tf"
expect_pass "scanner passes clean .java" \
  python3 "$scanner" "$tmp/scanner-clean-java/Config.java"

cat > "$tmp/pr.diff" <<'EOF'
diff --git a/example.py b/example.py
index 1111111..2222222 100644
--- a/example.py
+++ b/example.py
@@ -1 +1 @@
-print("old")
+print("new")
EOF

expect_pass \
  "AI review harness dry-run" \
  python3 "$here/ai_review.py" \
  --diff "$tmp/pr.diff" \
  --rubric "$here/../../.claude/agents/reviewer.md" \
  --dry-run

echo "selftest: $pass_count checks passed"
