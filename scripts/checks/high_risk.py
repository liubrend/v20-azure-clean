#!/usr/bin/env python3
"""Classify changed paths as high-risk per .github/high-risk-paths.

The path list (glob patterns, fnmatch) is the single source of truth for both
consumers: L4 (ai_review.py forces high on a match) and the L1-high-risk gate
(blocks a PR touching a match until it's acknowledged/reviewed).

Library:  high_risk(paths) -> sorted list of the paths that match.
CLI:      reads changed paths on stdin, prints the high-risk ones (one per line),
          exit 0 always (empty output = none matched).
"""
from __future__ import annotations

import fnmatch
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CONFIG = REPO / ".github" / "high-risk-paths"


def patterns(config: Path = CONFIG) -> list[str]:
    if not config.exists():
        return []
    out: list[str] = []
    for line in config.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line and not line.startswith("#"):
            out.append(line)
    return out


def high_risk(paths, pats: list[str] | None = None) -> list[str]:
    pats = patterns() if pats is None else pats
    return sorted({p for p in paths if any(fnmatch.fnmatch(p, pat) for pat in pats)})


def main() -> int:
    changed = [line.strip() for line in sys.stdin if line.strip()]
    for hit in high_risk(changed):
        print(hit)
    return 0


if __name__ == "__main__":
    sys.exit(main())
