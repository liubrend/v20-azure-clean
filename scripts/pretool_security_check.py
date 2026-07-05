"""PreToolUse security precheck hook for Claude Code tool calls.

Reuses the same scanner as the git pre-commit hook (security_precommit.py) so
tool calls are screened by the same rules as commits, before a file is
written or a command runs.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import security_precommit as scanner  # noqa: E402

TOOL_TEXT_FIELDS = {
    "Bash": ("command", "bash-command.sh"),
    "Write": ("content", None),
    "Edit": ("new_string", None),
    "NotebookEdit": ("new_source", None),
}


def extract_text_and_path(tool_name: str, tool_input: dict) -> tuple[str, str]:
    field, synthetic_path = TOOL_TEXT_FIELDS.get(tool_name, (None, None))
    if field is not None:
        text = str(tool_input.get(field, ""))
        path = synthetic_path or tool_input.get("file_path", f"{tool_name.lower()}-input.txt")
        return text, path
    return json.dumps(tool_input), f"{tool_name.lower()}-input.json"


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0

    tool_name = payload.get("tool_name", "")
    tool_input = payload.get("tool_input", {}) or {}
    text, path = extract_text_and_path(tool_name, tool_input)
    if not text.strip():
        return 0

    config = scanner.load_config()
    findings = scanner.scan_file(path, text, config)
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

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
