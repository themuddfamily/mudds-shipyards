#!/usr/bin/env python3
"""Fail-closed manifest for installer/update compatibility evidence.

The validator checks an operator-produced record only.  It never launches an
installer, mutates user data, or treats a signed artifact as distribution
permission.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
SEMVER = re.compile(r"^v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _version(value: Any) -> bool:
    return _text(value) and bool(SEMVER.fullmatch(value.strip()))


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    """Return contract violations; an empty list means valid evidence."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("release_version", "build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if not _version(value.get("release_version")):
        errors.append(f"{label}.release_version must be semantic version text")

    migrations = value.get("save_migrations")
    if not isinstance(migrations, list) or not migrations:
        errors.append(f"{label}.save_migrations must be a non-empty list")
    else:
        for index, migration in enumerate(migrations):
            prefix = f"{label}.save_migrations[{index}]"
            if not isinstance(migration, dict):
                errors.append(f"{prefix} must be an object")
                continue
            for key in ("from_schema", "to_schema", "status", "evidence"):
                if key not in migration:
                    errors.append(f"{prefix}.{key} is required")
            if not isinstance(migration.get("from_schema"), int) or migration.get("from_schema", 0) < 0:
                errors.append(f"{prefix}.from_schema must be a non-negative integer")
            if not isinstance(migration.get("to_schema"), int) or migration.get("to_schema", 0) < 0:
                errors.append(f"{prefix}.to_schema must be a non-negative integer")
            if migration.get("status") not in STATUSES:
                errors.append(f"{prefix}.status is invalid")
            if migration.get("status") in {"PASS", "FAIL"} and not _text(migration.get("evidence")):
                errors.append(f"{prefix}.evidence is required when migration ran")
            if migration.get("status") in {"NOT_RUN", "UNKNOWN"} and migration.get("evidence") is not None:
                errors.append(f"{prefix}.evidence must be null when migration did not run")

    signature = value.get("signature_status")
    if signature not in {"VERIFIED", "UNVERIFIED", "UNSIGNED", "UNKNOWN"}:
        errors.append(f"{label}.signature_status is invalid")
    if signature == "VERIFIED" and not _text(value.get("signature_evidence")):
        errors.append(f"{label}.signature_evidence is required when signature is VERIFIED")
    if signature != "VERIFIED" and value.get("signature_evidence") is not None:
        errors.append(f"{label}.signature_evidence must be null unless signature is VERIFIED")
    if value.get("signature_grants_distribution_rights") is not False:
        errors.append(f"{label}.signature_grants_distribution_rights must be false")

    native = value.get("native_update_status")
    if native not in STATUSES:
        errors.append(f"{label}.native_update_status is invalid")
    if native in {"PASS", "FAIL"} and not _text(value.get("native_update_evidence")):
        errors.append(f"{label}.native_update_evidence is required when native update ran")
    if native in {"NOT_RUN", "UNKNOWN"} and value.get("native_update_evidence") is not None:
        errors.append(f"{label}.native_update_evidence must be null when native update did not run")

    if value.get("install_or_update_executed") is not False:
        errors.append(f"{label}.install_or_update_executed must be false")
    artifact_hash = value.get("artifact_sha256")
    if artifact_hash is not None and (not _text(artifact_hash) or not HEX64.fullmatch(artifact_hash)):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest when provided")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("UPDATE_COMPATIBILITY_MANIFEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("UPDATE_COMPATIBILITY_MANIFEST_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
