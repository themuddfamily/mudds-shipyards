#!/usr/bin/env python3
"""Validate v15 authority-scoped snapshot manifest counts and digest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 15
EVIDENCE_SCOPE = "network_snapshot_manifest_count_digest_authority_v15"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _authority_digest(manifest: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{manifest.get('sequence')}|{manifest.get('root_digest')}".encode("utf-8")).hexdigest()


def _manifest_digest(entries: list[dict[str, Any]]) -> str:
    lines = [f"{entry.get('ordinal')}|{entry.get('entity_id')}|{entry.get('digest')}" for entry in entries]
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()


def validate_manifest(report: Any, label: str = "manifest") -> list[str]:
    """Return authority, ordered count/digest, and no-mutation errors."""

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

    manifest = report.get("manifest")
    if not isinstance(manifest, dict):
        errors.append(f"{label}.manifest must be an object")
        manifest = {}
    if manifest.get("authority") != AUTHORITY:
        errors.append(f"{label}.manifest.authority must be {AUTHORITY}")
    if not _sequence(manifest.get("sequence")):
        errors.append(f"{label}.manifest.sequence must be non-negative")
    if not _digest(manifest.get("root_digest")):
        errors.append(f"{label}.manifest.root_digest must be lowercase SHA-256")
    if not _digest(manifest.get("authority_digest")):
        errors.append(f"{label}.manifest.authority_digest must be lowercase SHA-256")
    elif manifest["authority_digest"] != _authority_digest(manifest):
        errors.append(f"{label}.manifest.authority_digest must anchor authority manifest")
    declared_count = manifest.get("declared_count")
    if not _sequence(declared_count):
        errors.append(f"{label}.manifest.declared_count must be non-negative")

    entries = report.get("entries")
    if not isinstance(entries, list):
        errors.append(f"{label}.entries must be an array")
        entries = []
    entity_ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if entry.get("ordinal") != index + 1:
            errors.append(f"{prefix}.ordinal must be {index + 1}")
        entity_id = entry.get("entity_id")
        if not isinstance(entity_id, str) or not entity_id:
            errors.append(f"{prefix}.entity_id must be non-empty")
        elif entity_id in entity_ids:
            errors.append(f"{prefix}.entity_id must be unique")
        else:
            entity_ids.add(entity_id)
        if entry.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if entry.get("authority_digest") != manifest.get("authority_digest"):
            errors.append(f"{prefix}.authority_digest must match manifest authority")
        if entry.get("sequence") != manifest.get("sequence"):
            errors.append(f"{prefix}.sequence must match manifest sequence")
        if not _digest(entry.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if entry.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if entry.get("mutation_fields") != [] or entry.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    if _sequence(declared_count) and declared_count != len(entries):
        errors.append(f"{label}.manifest.declared_count must match entry count")
    manifest_digest = report.get("manifest_digest")
    if not _digest(manifest_digest):
        errors.append(f"{label}.manifest_digest must be lowercase SHA-256")
    elif manifest_digest != _manifest_digest(entries):
        errors.append(f"{label}.manifest_digest must match ordered entries")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"entries": len(entries), "reconciled": reconciled_count, "mutations": mutation_count}
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
        print("NETWORK_SNAPSHOT_MANIFEST_COUNT_DIGEST_AUTHORITY_V15_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_MANIFEST_COUNT_DIGEST_AUTHORITY_V15_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
