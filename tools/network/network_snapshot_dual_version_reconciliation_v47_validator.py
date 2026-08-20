#!/usr/bin/env python3
"""Validate v47 dual-version snapshot reconciliation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 47
EVIDENCE_SCOPE = "network_snapshot_dual_version_reconciliation_v47"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
AUTHORITY_VERSION = 1
PROVENANCE_VERSION = 1
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _record_digest(record: dict[str, Any]) -> str:
    return hashlib.sha256(f"{record.get('authority')}|{record.get('authority_version')}|{record.get('provenance_version')}|{record.get('record_id')}|{record.get('expected_digest')}|{record.get('observed_digest')}".encode("utf-8")).hexdigest()


def _aggregate(records: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{record.get('order')}|{record.get('record_id')}|{record.get('reconciliation_digest')}" for record in records).encode("utf-8")).hexdigest()


def validate_reconciliation(report: Any, label: str = "reconciliation") -> list[str]:
    """Return dual-version state, record digest, aggregate, count, and mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE), ("policy_version", POLICY_VERSION), ("authority", AUTHORITY), ("authority_version", AUTHORITY_VERSION), ("provenance_version", PROVENANCE_VERSION)):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    before = report.get("before")
    after = report.get("after")
    for name, state in (("before", before), ("after", after)):
        if not isinstance(state, dict) or not _sequence(state.get("sequence")) or not _digest(state.get("digest")):
            errors.append(f"{label}.{name} must contain sequence and lowercase SHA-256 digest")
        elif state.get("authority") != AUTHORITY:
            errors.append(f"{label}.{name}.authority must be {AUTHORITY}")
    if isinstance(before, dict) and isinstance(after, dict) and before != after:
        errors.append(f"{label}.after must preserve before state")

    records = report.get("records")
    if not isinstance(records, list):
        errors.append(f"{label}.records must be an array")
        records = []
    ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if record.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        record_id = record.get("record_id")
        if not isinstance(record_id, str) or not record_id:
            errors.append(f"{prefix}.record_id must be non-empty")
        elif record_id in ids:
            errors.append(f"{prefix}.record_id must be unique")
        else:
            ids.add(record_id)
        if record.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if record.get("authority_version") != AUTHORITY_VERSION:
            errors.append(f"{prefix}.authority_version must be {AUTHORITY_VERSION}")
        if record.get("provenance_version") != PROVENANCE_VERSION:
            errors.append(f"{prefix}.provenance_version must be {PROVENANCE_VERSION}")
        if not _digest(record.get("expected_digest")) or not _digest(record.get("observed_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif record.get("expected_digest") != record.get("observed_digest"):
            errors.append(f"{prefix}.observed_digest must match expected digest")
        reconciliation_digest = record.get("reconciliation_digest")
        if not _digest(reconciliation_digest):
            errors.append(f"{prefix}.reconciliation_digest must be lowercase SHA-256")
        elif reconciliation_digest != _record_digest(record):
            errors.append(f"{prefix}.reconciliation_digest must bind both versions")
        if record.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    aggregate_digest = report.get("aggregate_digest")
    if not _digest(aggregate_digest):
        errors.append(f"{label}.aggregate_digest must be lowercase SHA-256")
    elif aggregate_digest != _aggregate(records):
        errors.append(f"{label}.aggregate_digest must match dual-version records")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"records": len(records), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match reconciliation records")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_reconciliation_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_reconciliation(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("reconciliation", type=Path)
    args = parser.parse_args()
    errors = validate_reconciliation_file(args.reconciliation)
    if errors:
        print("NETWORK_SNAPSHOT_DUAL_VERSION_RECONCILIATION_V47_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DUAL_VERSION_RECONCILIATION_V47_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
