"""PreToolUse security precheck hook for Claude Code tool calls.

Reuses the same scanner as the git pre-commit hook (security_precommit.py) so
tool calls are screened by the same rules as commits, before a file is
written or a command runs. On top of the content scan, two layers the
scanner cannot see:

- command policy: Bash/PowerShell commands that neuter the guardrail stack
  (hook bypass, hooksPath tampering, force push, pipe-to-shell) are blocked;
- guard-file protection: writes targeting the files that implement the
  guardrails surface a permission prompt ("ask") instead of passing
  silently -- the local mirror of CI's forced-high rule. Conservative, not
  exhaustive; CI's forced-high L4 gate is the backstop.

Exit codes: 0 = allow (an "ask" is exit 0 plus a permissionDecision JSON on
stdout), 2 = block. Fail-closed: scanner errors and undecodable payloads
block the call instead of passing it through.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

try:
    import security_precommit as scanner  # noqa: E402
except Exception as exc:  # a broken scanner must block, not wave through
    print(f"pretool precheck: cannot load scanner ({exc}) -- fail closed", file=sys.stderr)
    sys.exit(2)

# tool -> (text field, synthetic path, is_command, is_fragment)
TOOL_TEXT_FIELDS = {
    "Bash": ("command", "bash-command.sh", True, False),
    "PowerShell": ("command", "powershell-command.ps1", True, False),
    "Write": ("content", None, False, False),
    "Edit": ("new_string", None, False, True),
    "NotebookEdit": ("new_source", None, False, True),
}

# Commands that bypass or disarm the guardrail stack. Blocked outright.
COMMAND_POLICY = [
    (
        re.compile(r"git\b[^\n|;&]*\b(commit|push)\b[^\n|;&]*--no-verify"),
        "git --no-verify skips the pre-commit security hook (L1)",
    ),
    (
        re.compile(r"git\b[^\n]*-c\s*core\.hooksPath", re.IGNORECASE),
        "inline core.hooksPath override disarms the tracked git hooks",
    ),
    (
        re.compile(r"git\s+config\b(?![^\n]*\.githooks)[^\n]*core\.hooksPath", re.IGNORECASE),
        "re-pointing core.hooksPath away from .githooks disarms the L1 hook",
    ),
    (
        re.compile(r"git\s+push\b[^\n]*(\s--force\b|\s-f\b)"),
        "force push rewrites remote history; run it yourself if truly intended",
    ),
    (
        re.compile(r"(curl|wget)\b[^\n|]*\|\s*(ba|z|da)?sh\b"),
        "piping a download straight into a shell executes unreviewed code",
    ),
    (
        re.compile(
            r"(\biex\b|invoke-expression)\s*\(?\s*(\birm\b|invoke-restmethod|\biwr\b|invoke-webrequest)",
            re.IGNORECASE,
        ),
        "executing a downloaded string (iex/irm) runs unreviewed code",
    ),
]

# Files that implement the guardrails. Writing them is never silent.
GUARD_PATH_PREFIXES = (
    ".claude/",
    ".githooks/",
    ".github/workflows/",
    "scripts/checks/",
    "security/",
)
GUARD_FILES = (
    "AGENTS.md",
    "CLAUDE.md",
    "scripts/security_precommit.py",
    "scripts/pretool_security_check.py",
    "scripts/install_hooks.py",
)

_GUARD_ALT = "|".join(
    re.escape(p) for p in sorted(GUARD_PATH_PREFIXES) + sorted(GUARD_FILES)
)
# A mutation whose target sits right after the mutating token. Deliberately
# narrow: reading or mentioning a guard path stays silent.
GUARD_WRITE_RE = re.compile(
    r"(?:>>?\s*|\btee\s+(?:-a\s+)?|\brm\s+(?:-\w+\s+)*|\bmv\s+|\bcp\s+[\w./\"' -]*\s|\bsed\s+-i\S*\s+[^\n]*?)"
    r"[\"']?(?:\./)?[\w./ -]*(?:" + _GUARD_ALT + r")"
)


def normalize(path: str) -> str:
    return path.replace("\\", "/")


def is_guard_path(file_path: str) -> bool:
    p = normalize(file_path)
    for prefix in GUARD_PATH_PREFIXES:
        if p.startswith(prefix) or f"/{prefix}" in p:
            return True
    for name in GUARD_FILES:
        if p == name or p.endswith(f"/{name}"):
            return True
    return False


def extract_text_and_path(tool_name: str, tool_input: dict) -> tuple[str, str, bool, bool]:
    field, synthetic_path, is_command, is_fragment = TOOL_TEXT_FIELDS.get(
        tool_name, (None, None, False, False)
    )
    if field is not None:
        text = str(tool_input.get(field, ""))
        path = synthetic_path or tool_input.get("file_path", f"{tool_name.lower()}-input.txt")
        return text, path, is_command, is_fragment
    return json.dumps(tool_input), f"{tool_name.lower()}-input.json", False, False


def ask(reason: str) -> int:
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "ask",
                    "permissionDecisionReason": reason,
                }
            }
        )
    )
    return 0


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        print("pretool precheck: undecodable hook payload -- fail closed", file=sys.stderr)
        return 2

    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {}) or {}
    text, path, is_command, is_fragment = extract_text_and_path(tool_name, tool_input)
    if not text.strip():
        return 0

    if is_command:
        for pattern, reason in COMMAND_POLICY:
            if pattern.search(text):
                print(f"Security precheck blocked {tool_name} call: {reason}", file=sys.stderr)
                return 2

    config = scanner.load_config()
    findings = scanner.scan_file(path, text, config, fragment=is_fragment)
    threshold = config.get("fail_threshold", "high")

    if scanner.should_fail(findings, threshold):
        print(f"Security precheck blocked {tool_name} call:", file=sys.stderr)
        for finding in findings:
            print(
                f"  [{finding.code}] {finding.path}:{finding.line} "
                f"{finding.category} {finding.severity} - {finding.message}",
                file=sys.stderr,
            )
        print(
            "Resolve the finding(s) above, or update security/security_rules.json "
            "allowlists, before retrying this tool call.",
            file=sys.stderr,
        )
        return 2

    if tool_name in {"Write", "Edit", "NotebookEdit"}:
        target = str(tool_input.get("file_path", ""))
        if target and is_guard_path(target):
            return ask(
                f"{tool_name} targets guardrail file {target} -- policy/guard changes "
                "need explicit approval (local mirror of CI's forced-high rule)."
            )
    if is_command and GUARD_WRITE_RE.search(text):
        return ask(
            "Command appears to modify guardrail files (.claude/, .githooks/, "
            "scripts/checks/, security/, workflows) -- needs explicit approval."
        )

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception as exc:  # any unexpected crash blocks rather than passes
        print(f"pretool precheck: internal error ({exc}) -- fail closed", file=sys.stderr)
        raise SystemExit(2)
