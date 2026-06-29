"""Install tracked Git hooks for this repository."""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path
from typing import Sequence


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def git_root(repo: Path) -> Path:
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=str(repo),
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return Path(result.stdout.strip())


def hooks_path_for(repo: Path) -> str:
    root = git_root(repo)
    hooks_dir = PROJECT_ROOT / ".githooks"
    try:
        return hooks_dir.relative_to(root).as_posix()
    except ValueError:
        return hooks_dir.as_posix()


def install_hooks(repo: Path = PROJECT_ROOT) -> str:
    hooks_path = hooks_path_for(repo)
    subprocess.run(["git", "config", "core.hooksPath", hooks_path], cwd=str(repo), check=True)
    return hooks_path


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Configure Git to use tracked hooks from .githooks.")
    parser.add_argument("--repo", type=Path, default=PROJECT_ROOT, help="Repository root to configure.")
    args = parser.parse_args(argv)
    hooks_path = install_hooks(args.repo)
    print(f"Configured core.hooksPath={hooks_path} for {args.repo}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())