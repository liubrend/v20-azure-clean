# Thin task launcher. The important target is `make setup`, which installs the
# local L1 pre-commit hook so the secret scan runs before a commit lands — not
# only in CI (where a leaked secret has already reached the remote).
#
# No `make` (e.g. Windows Git Bash)? Run the command it wraps directly:
#   python scripts/install_hooks.py
.PHONY: help setup

help:
	@echo "Targets:"
	@echo "  make setup   Install local git hooks (L1 pre-commit security scan)"

setup:
	python scripts/install_hooks.py
	@echo "Local hooks installed — the L1 secret scan now runs on every commit."
