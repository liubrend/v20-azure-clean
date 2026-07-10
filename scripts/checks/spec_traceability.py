#!/usr/bin/env python3
"""L2 spec-traceability gate.

Every Given/When/Then scenario in a spec must be covered by a test that
references it, so a spec change can't merge with stale or missing coverage.

Convention:
  - A spec lives at docs/specs/spec-NNN[-name].md and has scenarios written as
    `### S1 — ...`, `### S2 — ...` (see docs/specs/spec-template.md).
  - A test COVERS a scenario by including the token `spec-NNN:S<n>` anywhere in
    the test file — a JUnit @DisplayName, a Jasmine it(...) title, or a comment.
    Example: @DisplayName("spec-003:S2 rejects a market order")

The template (spec-template.md) and README are ignored; only real specs
(spec-<digits>...) are checked. With no specs yet this passes trivially — the
gate is ready for when specs land.

exit 0 = every scenario covered   1 = an uncovered scenario   2 = could-not-verify
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC_GLOB = "docs/specs/spec-[0-9]*.md"
TEST_GLOBS = (
    "src/backend/**/src/test/**/*.java",
    "src/backend/**/src/integrationTest/**/*.java",
    "src/frontend/**/*.spec.ts",
    "tests/**/*",
)
SCENARIO_RE = re.compile(r"^#{2,3}\s*(S\d+)\b", re.MULTILINE)
SPEC_ID_RE = re.compile(r"(spec-\d+)", re.IGNORECASE)


def spec_id_for(path: Path, text: str) -> str | None:
    first_line = text.split("\n", 1)[0]
    match = SPEC_ID_RE.search(first_line) or SPEC_ID_RE.search(path.name)
    return match.group(1).lower() if match else None


def load_test_corpus(root: Path) -> str:
    parts: list[str] = []
    for pattern in TEST_GLOBS:
        for path in root.glob(pattern):
            if path.is_file():
                try:
                    parts.append(path.read_text(encoding="utf-8", errors="replace"))
                except OSError:
                    pass
    return "\n".join(parts).lower()


def check(root: Path = REPO) -> tuple[int, list[str]]:
    specs = sorted(root.glob(SPEC_GLOB))
    if not specs:
        return 0, []
    corpus = load_test_corpus(root)
    errors: list[str] = []
    for spec in specs:
        rel = spec.relative_to(root).as_posix()
        text = spec.read_text(encoding="utf-8", errors="replace")
        sid = spec_id_for(spec, text)
        if not sid:
            errors.append(f"{rel}: cannot determine spec id (need a `# spec-NNN` header or spec-NNN filename)")
            continue
        scenarios = SCENARIO_RE.findall(text)
        if not scenarios:
            errors.append(f"{rel}: no `S<n>` scenarios found (spec must define Given/When/Then scenarios)")
            continue
        for scenario in scenarios:
            token = f"{sid}:{scenario}".lower()
            if token not in corpus:
                errors.append(f"{rel}: scenario {scenario} has no test referencing `{sid}:{scenario}`")
    return (1 if errors else 0), errors


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO  # arg = root, for selftest fixtures
    code, errors = check(root)
    if errors:
        print("spec-traceability: VIOLATION", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return code
    specs = sorted(root.glob(SPEC_GLOB))
    if not specs:
        print("spec-traceability: no specs yet — nothing to check")
    else:
        print(f"spec-traceability: clean ({len(specs)} spec(s) fully covered)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
