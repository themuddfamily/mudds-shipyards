#!/usr/bin/env python3
"""Validate v24 direct snapshot identity reconciliation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 24
EVIDENCE_SCOPE = "network_snapshot_identity_reconciliation_authority_v24"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _anchor_digest(anchor: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{anchor.get('anchor_id')}|{anchor.get('sequence')}|{anchor.get('digest')}".encode("utf-8")).hexdigest()


def _identity_digest(anchor: dict[str, Any], record: dict[str, Any]) -> str:
    return hashlib.sha256(f"{anchor.get('anchor_digest')}|{record.get('identity_id')}|{record.get('source_digest')}".encode("utf-8")).hexdigest()


def validate_identity(report: Any, label: str = "identity") -> list[str]:
    """Return anchor, identity agreement, count, and no-mutation errors."""

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
        if not isinstance(state, dict) or not _sequence(state.get("sequence")) or not _digest(state.get("digest")):
            errors.append(f"{label}.{name} must contain sequence and lowercase SHA-256 digest")
        elif state.get("authority") != AUTHORITY:
            errors.append(f"{label}.{name}.authority must be {AUTHORITY}")
    if isinstance(before, dict) and isinstance(after, dict) and before != after:
        errors.append(f"{label}.after must preserve before state")

    anchor = report.get("anchor")
    if not isinstance(anchor, dict):
        errors.append(f"{label}.anchor must be an object")
        anchor = {}
    if anchor.get("authority") != AUTHORITY:
        errors.append(f"{label}.anchor.authority must be {AUTHORITY}")
    if not isinstance(anchor.get("anchor_id"), str) or not anchor.get("anchor_id"):
        errors.append(f"{label}.anchor.anchor_id must be non-empty")
    if not _sequence(anchor.get("sequence")):
        errors.append(f"{label}.anchor.sequence must be non-negative")
    if not _digest(anchor.get("digest")):
        errors.append(f"{label}.anchor.digest must be lowercase SHA-256")
    if not _digest(anchor.get("anchor_digest")):
        errors.append(f"{label}.anchor.anchor_digest must be lowercase SHA-256")
    elif anchor["anchor_digest"] != _anchor_digest(anchor):
        errors.append(f"{label}.anchor.anchor_digest must bind authority anchor")

    records = report.get("records")
    if not isinstance(records, list):
        errors.append(f"{label}.records must be an array")
        records = []
    identity_ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if record.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        identity_id = record.get("identity_id")
        if not isinstance(identity_id, str) or not identity_id:
            errors.append(f"{prefix}.identity_id must be non-empty")
        elif identity_id in identity_ids:
            errors.append(f"{prefix}.identity_id must be unique")
        else:
            identity_ids.add(identity_id)
        if record.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if record.get("anchor_digest") != anchor.get("anchor_digest"):
            errors.append(f"{prefix}.anchor_digest must match anchor")
        if record.get("sequence") != anchor.get("sequence"):
            errors.append(f"{prefix}.sequence must match anchor")
        if not _digest(record.get("source_digest")) or not _digest(record.get("resolved_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif record.get("resolved_digest") != record.get("source_digest"):
            errors.append(f"{prefix}.resolved_digest must match source digest")
        if not _digest(record.get("identity_digest")):
            errors.append(f"{prefix}.identity_digest must be lowercase SHA-256")
        elif record["identity_digest"] != _identity_digest(anchor, record):
            errors.append(f"{prefix}.identity_digest must bind identity record")
        if record.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"records": len(records), "unique": len(identity_ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match identity records")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_identity_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_identity(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identity", type=Path)
    args = parser.parse_args()
    errors = validate_identity_file(args.identity)
    if errors:
        print("NETWORK_SNAPSHOT_IDENTITY_RECONCILIATION_AUTHORITY_V24_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_IDENTITY_RECONCILIATION_AUTHORITY_V24_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
