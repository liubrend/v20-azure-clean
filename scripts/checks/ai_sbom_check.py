#!/usr/bin/env python3
"""ASI04 (Agentic Supply Chain Vulnerabilities) gate.

Validates security/ai_sbom.json against the repo: every declared model is
version-pinned, every declared tool-definition file's hash still matches (so a
schema edit without a manifest bump fails the build instead of shipping
silently), and every declared data source has an explicit trust classification.

This is a CI-time check, not a runtime hook (see security/ai_sbom.json):
nothing here depends on a live request, only on committed state, so it
belongs next to forbid.sh in the L1-policy job, not in the request path.

Fail-closed, matching forbid.sh's convention:
  exit 0 = clean   exit 1 = violation found   exit 2 = could-not-verify
"""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = REPO_ROOT / "security" / "ai_sbom.json"


def hash_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_manifest() -> dict:
    if not MANIFEST_PATH.exists():
        print(f"ai_sbom_check: manifest not found: {MANIFEST_PATH} -- fail closed", file=sys.stderr)
        sys.exit(2)
    try:
        return json.loads(MANIFEST_PATH.read_text())
    except json.JSONDecodeError as e:
        print(f"ai_sbom_check: manifest is not valid JSON: {e} -- fail closed", file=sys.stderr)
        sys.exit(2)


def check_model_pins(manifest: dict) -> list[str]:
    errors = []
    for entry in manifest.get("models", []):
        if entry.get("version") in (None, "", "latest"):
            errors.append(f"model '{entry.get('name')}' is not pinned to a specific version")
    return errors


def check_tool_schemas(manifest: dict) -> list[str]:
    errors = []
    for entry in manifest.get("tool_definitions", []):
        schema_path = REPO_ROOT / entry["path"]
        if not schema_path.exists():
            errors.append(f"tool schema missing on disk: {entry['path']}")
            continue
        actual = hash_file(schema_path)
        if actual != entry["sha256"]:
            errors.append(
                f"tool schema '{entry['path']}' changed without manifest update "
                f"(expected {entry['sha256'][:12]}..., got {actual[:12]}...)"
            )
    return errors


def check_data_sources(manifest: dict) -> list[str]:
    errors = []
    for entry in manifest.get("data_sources", []):
        if entry.get("trust_level") not in {"internal", "vetted-vendor"}:
            errors.append(
                f"data source '{entry.get('name')}' has unrecognized trust_level "
                f"'{entry.get('trust_level')}' -- must be internal or vetted-vendor"
            )
    return errors


def main() -> int:
    manifest = load_manifest()
    errors = [
        *check_model_pins(manifest),
        *check_tool_schemas(manifest),
        *check_data_sources(manifest),
    ]

    if errors:
        print("ai_sbom_check: VIOLATION", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(
        f"ai_sbom_check: clean "
        f"({len(manifest.get('models', []))} models, "
        f"{len(manifest.get('tool_definitions', []))} tool schemas, "
        f"{len(manifest.get('data_sources', []))} data sources)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
