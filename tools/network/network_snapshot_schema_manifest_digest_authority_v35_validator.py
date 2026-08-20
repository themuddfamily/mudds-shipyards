#!/usr/bin/env python3
"""Validate v35 schema/manifest digest authority evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 35
EVIDENCE_SCOPE = "network_snapshot_schema_manifest_digest_authority_v35"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SCHEMA_NAME = "snapshot"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _manifest_digest(manifest: dict[str, Any]) -> str:
    payload = f"{AUTHORITY}|{manifest.get('manifest_id')}|{manifest.get('schema_version')}|{manifest.get('sequence')}|{manifest.get('digest')}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_manifest(report: Any, label: str = "manifest") -> list[str]:
    """Return schema, manifest digest, entry, count, and no-mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
        ("authority", AUTHORITY),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    schema = report.get("snapshot_schema")
    if not isinstance(schema, dict):
        errors.append(f"{label}.snapshot_schema must be an object")
        schema = {}
    if schema.get("name") != SCHEMA_NAME:
        errors.append(f"{label}.snapshot_schema.name must be {SCHEMA_NAME}")
    if not _positive_int(schema.get("version")):
        errors.append(f"{label}.snapshot_schema.version must be positive")

    manifest = report.get("manifest")
    if not isinstance(manifest, dict):
        errors.append(f"{label}.manifest must be an object")
        manifest = {}
    if manifest.get("authority") != AUTHORITY:
        errors.append(f"{label}.manifest.authority must be {AUTHORITY}")
    if not isinstance(manifest.get("manifest_id"), str) or not manifest.get("manifest_id"):
        errors.append(f"{label}.manifest.manifest_id must be non-empty")
    if manifest.get("schema_version") != schema.get("version"):
        errors.append(f"{label}.manifest.schema_version must match snapshot schema")
    if not _sequence(manifest.get("sequence")):
        errors.append(f"{label}.manifest.sequence must be non-negative")
    if not _digest(manifest.get("digest")):
        errors.append(f"{label}.manifest.digest must be lowercase SHA-256")
    manifest_digest = manifest.get("manifest_digest")
    if not _digest(manifest_digest):
        errors.append(f"{label}.manifest.manifest_digest must be lowercase SHA-256")
    elif manifest_digest != _manifest_digest(manifest):
        errors.append(f"{label}.manifest.manifest_digest must bind schema manifest")

    entries = report.get("entries")
    if not isinstance(entries, list):
        errors.append(f"{label}.entries must be an array")
        entries = []
    ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if entry.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        entry_id = entry.get("entry_id")
        if not isinstance(entry_id, str) or not entry_id:
            errors.append(f"{prefix}.entry_id must be non-empty")
        elif entry_id in ids:
            errors.append(f"{prefix}.entry_id must be unique")
        else:
            ids.add(entry_id)
        if entry.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if entry.get("manifest_id") != manifest.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest")
        if entry.get("schema_version") != schema.get("version"):
            errors.append(f"{prefix}.schema_version must match schema")
        if entry.get("manifest_digest") != manifest_digest:
            errors.append(f"{prefix}.manifest_digest must match manifest")
        if not _digest(entry.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if entry.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if entry.get("mutation_fields") != [] or entry.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"entries": len(entries), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match manifest entries")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_manifest_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_manifest(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate_manifest_file(args.manifest)
    if errors:
        print("NETWORK_SNAPSHOT_SCHEMA_MANIFEST_DIGEST_AUTHORITY_V35_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_SCHEMA_MANIFEST_DIGEST_AUTHORITY_V35_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
