"""Dependency-free staged-file security scanner for v20-Azure-clean-teamsEnabled commits."""

from __future__ import annotations

import argparse
import ast
import fnmatch
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Sequence


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_RULES = PROJECT_ROOT / "security" / "security_rules.json"

TEXT_EXTENSIONS = {
    ".cfg",
    ".conf",
    ".css",
    ".env",
    ".gradle",
    ".html",
    ".ini",
    ".java",
    ".js",
    ".json",
    ".jsx",
    ".kt",
    ".kts",
    ".md",
    ".mjs",
    ".properties",
    ".ps1",
    ".py",
    ".scss",
    ".sh",
    ".sql",
    ".tf",
    ".tfvars",
    ".toml",
    ".ts",
    ".tsx",
    ".txt",
    ".xml",
    ".yaml",
    ".yml",
}

SCANNABLE_FILENAMES = {"AGENTS.md", "CLAUDE.md", "pre-commit", "Dockerfile", ".env"}

LOCAL_IMPORTS = {"tests", "scripts", "app", "frontend", "backend"}
SEVERITY_ORDER = {"info": 0, "warn": 1, "medium": 2, "high": 3}
PROMPT_INJECTION_PATTERNS = [
    re.compile(r"ignore\s+(all\s+)?previous\s+instructions?", re.IGNORECASE),
    re.compile(r"reveal\s+(the\s+)?system\s+prompt", re.IGNORECASE),
    re.compile(r"disable\s+(all\s+)?safety", re.IGNORECASE),
    re.compile(r"bypass\s+(the\s+)?(policy|safety|guardrails?)", re.IGNORECASE),
]
USER_PROMPT_CONCAT = re.compile(
    r"(prompt|system_message|developer_message)\s*=\s*f?[\"'][^\"'\n]*(user|input|message|query)",
    re.IGNORECASE,
)
SQL_KEYWORDS = re.compile(r"\b(SELECT|INSERT|UPDATE|DELETE|DROP|ALTER)\b", re.IGNORECASE)
EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.IGNORECASE)
PHONE_RE = re.compile(r"\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]\d{3}[-.\s]\d{4}\b")
PRIVATE_KEY_RE = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")
SECRET_ASSIGNMENT_RE = re.compile(
    r"(?i)\b(api[_-]?key|secret|token|password)\b\s*[:=]\s*[\"'][A-Za-z0-9_./+=-]{16,}[\"']"
)


@dataclass(frozen=True)
class Finding:
    code: str
    path: str
    line: int
    severity: str
    category: str
    message: str


def load_config(path: Path = DEFAULT_RULES) -> dict:
    if not path.exists():
        return {
            "fail_threshold": "high",
            "allowed_external_imports": [],
            "ignored_path_patterns": [],
            "pii_allowlist_patterns": [],
        }
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def discover_git_root(start: Path) -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=str(start),
        check=False,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode == 0 and result.stdout.strip():
        return Path(result.stdout.strip())
    return start


GIT_ROOT = discover_git_root(PROJECT_ROOT)


def project_path(path: str) -> str:
    normalized = path.replace("\\", "/")
    prefix = PROJECT_ROOT.name + "/"
    if normalized.startswith(prefix):
        return normalized[len(prefix):]
    return normalized


def git(args: Sequence[str], cwd: Path = GIT_ROOT, check: bool = True) -> subprocess.CompletedProcess[str]:
    # Force UTF-8 decoding: without it, text=True uses the locale codec (cp1252
    # on Windows), which crashes on non-ASCII bytes in staged content/diffs when
    # this runs as the pre-commit hook. errors="replace" keeps the scan resilient.
    return subprocess.run(
        ["git", *args],
        cwd=str(cwd),
        check=check,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def staged_paths(cwd: Path = GIT_ROOT) -> list[str]:
    result = git(["diff", "--cached", "--name-only", "--diff-filter=ACMR"], cwd=cwd)
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def staged_content(path: str, cwd: Path = GIT_ROOT) -> str | None:
    result = git(["show", f":{path}"], cwd=cwd, check=False)
    if result.returncode != 0:
        return None
    try:
        return result.stdout
    except UnicodeDecodeError:
        return None


def working_tree_content(path: str, cwd: Path = GIT_ROOT) -> str | None:
    file_path = cwd / path
    if not file_path.exists():
        file_path = PROJECT_ROOT / path
    if not file_path.exists() or not file_path.is_file():
        return None
    try:
        return file_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return None


def is_scannable(path: str, ignored_patterns: Iterable[str]) -> bool:
    normalized = project_path(path)
    if any(fnmatch.fnmatch(normalized, pattern) for pattern in ignored_patterns):
        return False
    if Path(normalized).suffix.lower() in TEXT_EXTENSIONS:
        return True
    return Path(normalized).name in SCANNABLE_FILENAMES


def is_review_path(path: str) -> bool:
    normalized = project_path(path)
    return normalized.startswith(("docs/", "tests/", "data/"))


def line_for_offset(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def allowed_by_pattern(text: str, allowlist: Iterable[str]) -> bool:
    return any(pattern and pattern in text for pattern in allowlist)


def scan_prompt_injection(path: str, text: str) -> list[Finding]:
    findings: list[Finding] = []
    severity = "warn" if is_review_path(path) else "high"
    for pattern in PROMPT_INJECTION_PATTERNS:
        for match in pattern.finditer(text):
            findings.append(
                Finding(
                    "SEC001",
                    path,
                    line_for_offset(text, match.start()),
                    severity,
                    "prompt-injection",
                    f"Prompt-injection phrase detected: {match.group(0)!r}",
                )
            )
    for match in USER_PROMPT_CONCAT.finditer(text):
        findings.append(
            Finding(
                "SEC002",
                path,
                line_for_offset(text, match.start()),
                "warn",
                "prompt-injection",
                "Potential user-controlled prompt construction needs review.",
            )
        )
    return findings


def stdlib_modules() -> set[str]:
    names = getattr(sys, "stdlib_module_names", set())
    return set(names) | set(sys.builtin_module_names)


def scan_imports(
    path: str, text: str, allowed_external: Iterable[str], fragment: bool = False
) -> list[Finding]:
    if not path.endswith(".py"):
        return []
    try:
        tree = ast.parse(text, filename=path)
    except SyntaxError as exc:
        if fragment:
            # An Edit/NotebookEdit fragment is not a complete file; a parse
            # failure is expected there, not a finding. The staged-file scan
            # at commit time still sees the whole file with full context.
            return []
        return [
            Finding(
                "SEC010",
                path,
                exc.lineno or 1,
                "high",
                "python-parse",
                "Python file cannot be parsed for import scanning.",
            )
        ]
    allowed = set(allowed_external) | LOCAL_IMPORTS | stdlib_modules()
    findings: list[Finding] = []
    for node in ast.walk(tree):
        names: list[tuple[str, int]] = []
        if isinstance(node, ast.Import):
            names = [(alias.name.split(".")[0], node.lineno) for alias in node.names]
        elif isinstance(node, ast.ImportFrom) and node.module and node.level == 0:
            names = [(node.module.split(".")[0], node.lineno)]
        for module, line in names:
            if module not in allowed:
                findings.append(
                    Finding(
                        "SEC011",
                        path,
                        line,
                        "high",
                        "hallucinated-dependency",
                        f"Unknown external import {module!r}; add dependency or allowlist it.",
                    )
                )
    return findings


def is_sql_execute_call(node: ast.Call) -> bool:
    func = node.func
    if isinstance(func, ast.Attribute):
        return func.attr in {"execute", "executemany", "executescript"}
    if isinstance(func, ast.Name):
        return func.id in {"execute", "executemany", "executescript"}
    return False


def sql_arg_is_unsafe(node: ast.AST) -> bool:
    if isinstance(node, ast.JoinedStr):
        return True
    if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Mod)):
        return True
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
        return node.func.attr == "format"
    return False


def scan_sql(path: str, text: str) -> list[Finding]:
    findings: list[Finding] = []
    if path.endswith(".py"):
        try:
            tree = ast.parse(text, filename=path)
        except SyntaxError:
            tree = None
        if tree is not None:
            for node in ast.walk(tree):
                if isinstance(node, ast.Call) and is_sql_execute_call(node) and node.args:
                    if sql_arg_is_unsafe(node.args[0]):
                        findings.append(
                            Finding(
                                "SEC020",
                                path,
                                node.lineno,
                                "high",
                                "sql-injection",
                                "Dynamic SQL passed to execute-style call.",
                            )
                        )
    if not findings and SQL_KEYWORDS.search(text) and "execute" not in text.lower():
        match = SQL_KEYWORDS.search(text)
        assert match is not None
        findings.append(
            Finding(
                "SEC021",
                path,
                line_for_offset(text, match.start()),
                "warn",
                "sql-injection",
                "SQL-like text detected without an execute call; review if user controlled.",
            )
        )
    return findings


def scan_pii(path: str, text: str, allowlist: Iterable[str]) -> list[Finding]:
    findings: list[Finding] = []
    for code, pattern, severity, message in [
        ("SEC030", PRIVATE_KEY_RE, "high", "Private key marker detected."),
        ("SEC031", SECRET_ASSIGNMENT_RE, "high", "Hard-coded secret-like assignment detected."),
        ("SEC034", EMAIL_RE, "warn", "Email address detected."),
        ("SEC035", PHONE_RE, "warn", "Phone number detected."),
    ]:
        for match in pattern.finditer(text):
            value = match.group(0)
            if allowed_by_pattern(value, allowlist):
                continue
            if severity == "warn" and is_review_path(path):
                continue
            findings.append(
                Finding(code, path, line_for_offset(text, match.start()), severity, "pii-leakage", message)
            )
    return findings


def scan_file(path: str, text: str, config: dict, fragment: bool = False) -> list[Finding]:
    allowed_imports = config.get("allowed_external_imports", [])
    pii_allowlist = config.get("pii_allowlist_patterns", [])
    prompt_allowlist_paths = config.get("prompt_injection_allowlist_paths", [])
    findings: list[Finding] = []
    normalized = project_path(path)
    if not any(fnmatch.fnmatch(normalized, pattern) for pattern in prompt_allowlist_paths):
        findings.extend(scan_prompt_injection(path, text))
    findings.extend(scan_imports(path, text, allowed_imports, fragment=fragment))
    findings.extend(scan_sql(path, text))
    findings.extend(scan_pii(path, text, pii_allowlist))
    return sorted(findings, key=lambda item: (item.path, item.line, item.code, item.message))


def scan_paths(paths: Sequence[str], *, staged: bool, cwd: Path, config: dict) -> tuple[list[Finding], int]:
    ignored_patterns = config.get("ignored_path_patterns", [])
    findings: list[Finding] = []
    checked = 0
    for path in paths:
        if not is_scannable(path, ignored_patterns):
            continue
        text = staged_content(path, cwd=cwd) if staged else working_tree_content(path, cwd=cwd)
        if text is None:
            continue
        checked += 1
        findings.extend(scan_file(path, text, config))
    return sorted(findings, key=lambda item: (item.path, item.line, item.code, item.message)), checked


def should_fail(findings: Iterable[Finding], threshold: str) -> bool:
    threshold_value = SEVERITY_ORDER.get(threshold, SEVERITY_ORDER["high"])
    return any(SEVERITY_ORDER.get(finding.severity, 0) >= threshold_value for finding in findings)


def print_report(findings: Sequence[Finding], checked: int, threshold: str) -> None:
    print("v20-Azure-clean-teamsEnabled security pre-commit scan")
    print(f"Checked {checked} file(s). Fail threshold: {threshold}.")
    if not findings:
        print("No security findings.")
        return
    for finding in findings:
        level = "ERROR" if finding.severity == "high" else "WARN"
        print(
            f"{level} [{finding.code}] {finding.path}:{finding.line} "
            f"{finding.category} {finding.severity} - {finding.message}"
        )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Scan staged files for high-risk security issues.")
    parser.add_argument("--staged", action="store_true", help="Scan staged Git blob content.")
    parser.add_argument("--config", type=Path, default=DEFAULT_RULES, help="Security rules JSON path.")
    parser.add_argument("--repo", type=Path, default=GIT_ROOT, help="Git repository root.")
    parser.add_argument("paths", nargs="*", help="Optional paths to scan instead of discovering staged paths.")
    args = parser.parse_args(argv)

    config = load_config(args.config)
    paths = args.paths if args.paths else staged_paths(cwd=args.repo)
    findings, checked = scan_paths(paths, staged=args.staged, cwd=args.repo, config=config)
    threshold = config.get("fail_threshold", "high")
    print_report(findings, checked, threshold)
    return 1 if should_fail(findings, threshold) else 0


if __name__ == "__main__":
    raise SystemExit(main())