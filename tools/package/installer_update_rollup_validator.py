#!/usr/bin/env python3
"""Validate installer/update compatibility evidence without executing it.

The rollup joins one artifact identity to installer, save-migration, and
native-update observations.  It is deliberately an evidence contract: this
tool never launches an installer, changes user data, or upgrades a package.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")
SEMVER = re.compile(r"^v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


def _evidence(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    status = record.get("status")
    if status not in STATUSES:
        errors.append(f"{label}.status is invalid")
        return
    evidence = record.get("evidence")
    if status == "PASS" and not _text(evidence):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and evidence is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_rollup(value: Any, label: str = "rollup") -> list[str]:
    """Return contract violations; an empty list means structurally valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("release_version", "build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("release_version")) and not SEMVER.fullmatch(value["release_version"].strip()):
        errors.append(f"{label}.release_version must be semantic version text")
    if value.get("artifact_sha256") is not None and not _digest(value.get("artifact_sha256")):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest when provided")

    installer = value.get("installer")
    _evidence(installer, f"{label}.installer", errors)
    if isinstance(installer, dict) and installer.get("status") == "PASS":
        for key in ("path", "sha256", "provenance"):
            if not _text(installer.get(key)):
                errors.append(f"{label}.installer.{key} is required when status is PASS")
        if not _digest(installer.get("sha256")):
            errors.append(f"{label}.installer.sha256 must be a 64-character hex digest")

    migration = value.get("save_migration")
    _evidence(migration, f"{label}.save_migration", errors)
    if isinstance(migration, dict) and migration.get("status") == "PASS":
        for key in ("from_schema", "to_schema"):
            if not isinstance(migration.get(key), int) or migration[key] < 0:
                errors.append(f"{label}.save_migration.{key} must be a non-negative integer")
        if migration.get("from_schema") == migration.get("to_schema"):
            errors.append(f"{label}.save_migration schemas must differ when status is PASS")

    native = value.get("native_update")
    _evidence(native, f"{label}.native_update", errors)
    if isinstance(native, dict) and native.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_update.{key} must be null when status is {native['status']}")
    if value.get("install_or_update_executed") is not False:
        errors.append(f"{label}.install_or_update_executed must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_rollup(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("INSTALLER_UPDATE_ROLLUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("INSTALLER_UPDATE_ROLLUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
