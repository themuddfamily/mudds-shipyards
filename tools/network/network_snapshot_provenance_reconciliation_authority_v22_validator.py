#!/usr/bin/env python3
"""Validate v22 provenance reconciliation authority evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 22
EVIDENCE_SCOPE = "network_snapshot_provenance_reconciliation_authority_v22"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _state(value: Any) -> bool:
    return isinstance(value, dict) and _sequence(value.get("sequence")) and _digest(value.get("digest"))


def _provenance_digest(records: list[dict[str, Any]]) -> str:
    payload = "\n".join(f"{record.get('order')}|{record.get('provenance_id')}|{record.get('expected_digest')}|{record.get('observed_digest')}" for record in records)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_provenance(report: Any, label: str = "provenance") -> list[str]:
    """Return provenance identity, state, digest, count, and mutation errors."""

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

    before = report.get("before")
    after = report.get("after")
    for name, state in (("before", before), ("after", after)):
        if not _state(state):
            errors.append(f"{label}.{name} must contain sequence and lowercase SHA-256 digest")
        elif state.get("authority") != AUTHORITY:
            errors.append(f"{label}.{name}.authority must be {AUTHORITY}")
    if _state(before) and _state(after) and before != after:
        errors.append(f"{label}.after must preserve before state")

    records = report.get("records")
    if not isinstance(records, list):
        errors.append(f"{label}.records must be an array")
        records = []
    provenance_ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        order = index + 1
        if record.get("order") != order:
            errors.append(f"{prefix}.order must be {order}")
        check_id = record.get("check_id")
        provenance_id = record.get("provenance_id")
        expected_provenance = f"{AUTHORITY}|{check_id}|{order}"
        if provenance_id != expected_provenance:
            errors.append(f"{prefix}.provenance_id must be {expected_provenance}")
        if not isinstance(provenance_id, str) or provenance_id in provenance_ids:
            errors.append(f"{prefix}.provenance_id must be unique")
        elif isinstance(provenance_id, str):
            provenance_ids.add(provenance_id)
        if record.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if not _digest(record.get("expected_digest")):
            errors.append(f"{prefix}.expected_digest must be lowercase SHA-256")
        if not _digest(record.get("observed_digest")):
            errors.append(f"{prefix}.observed_digest must be lowercase SHA-256")
        elif record.get("observed_digest") != record.get("expected_digest"):
            errors.append(f"{prefix}.observed_digest must match expected digest")
        if record.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    provenance_digest = report.get("provenance_digest")
    if not _digest(provenance_digest):
        errors.append(f"{label}.provenance_digest must be lowercase SHA-256")
    elif provenance_digest != _provenance_digest(records):
        errors.append(f"{label}.provenance_digest must match ordered provenance")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"records": len(records), "unique": len(provenance_ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match provenance records")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_provenance_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_provenance(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provenance", type=Path)
    args = parser.parse_args()
    errors = validate_provenance_file(args.provenance)
    if errors:
        print("NETWORK_SNAPSHOT_PROVENANCE_RECONCILIATION_AUTHORITY_V22_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_PROVENANCE_RECONCILIATION_AUTHORITY_V22_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
