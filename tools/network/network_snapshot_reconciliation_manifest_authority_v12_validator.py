#!/usr/bin/env python3
"""Validate v12 authority-scoped snapshot reconciliation manifests."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 12
EVIDENCE_SCOPE = "network_snapshot_reconciliation_manifest_authority_v12"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _authority_digest(root: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{root.get('sequence')}|{root.get('digest')}".encode("utf-8")).hexdigest()


def _manifest_digest(entries: list[dict[str, Any]]) -> str:
    lines = [f"{entry.get('entity_id')}|{entry.get('sequence')}|{entry.get('digest')}" for entry in entries]
    return hashlib.sha256("\n".join(lines).encode("utf-8")).hexdigest()


def validate_manifest(report: Any, label: str = "manifest") -> list[str]:
    """Return root, manifest, count, and no-mutation errors."""

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

    root = report.get("root")
    if not isinstance(root, dict):
        errors.append(f"{label}.root must be an object")
        root = {}
    if root.get("authority") != AUTHORITY:
        errors.append(f"{label}.root.authority must be {AUTHORITY}")
    if not _sequence(root.get("sequence")):
        errors.append(f"{label}.root.sequence must be non-negative")
    if not _digest(root.get("digest")):
        errors.append(f"{label}.root.digest must be lowercase SHA-256")
    if not _digest(root.get("authority_digest")):
        errors.append(f"{label}.root.authority_digest must be lowercase SHA-256")
    elif root["authority_digest"] != _authority_digest(root):
        errors.append(f"{label}.root.authority_digest must anchor root authority state")

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
        entity_id = entry.get("entity_id")
        if not isinstance(entity_id, str) or not entity_id:
            errors.append(f"{prefix}.entity_id must be non-empty")
        elif entity_id in entity_ids:
            errors.append(f"{prefix}.entity_id must be unique")
        else:
            entity_ids.add(entity_id)
        if entry.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if entry.get("root_digest") != root.get("authority_digest"):
            errors.append(f"{prefix}.root_digest must match root authority digest")
        if entry.get("sequence") != root.get("sequence"):
            errors.append(f"{prefix}.sequence must match root sequence")
        if not _digest(entry.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if entry.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if entry.get("mutation_fields") != [] or entry.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    manifest_digest = report.get("manifest_digest")
    if not _digest(manifest_digest):
        errors.append(f"{label}.manifest_digest must be lowercase SHA-256")
    elif manifest_digest != _manifest_digest(entries):
        errors.append(f"{label}.manifest_digest must match canonical entries")

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
        print("NETWORK_SNAPSHOT_RECONCILIATION_MANIFEST_AUTHORITY_V12_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_RECONCILIATION_MANIFEST_AUTHORITY_V12_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
