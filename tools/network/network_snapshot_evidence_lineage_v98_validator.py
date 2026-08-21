#!/usr/bin/env python3
"""Validate detached v98 snapshot evidence/lineage evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 98
EVIDENCE_SCOPE = "network_snapshot_evidence_lineage_v98"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
EVIDENCE_ID = "snapshot-evidence-v3"
LINEAGE = "snapshot-lineage-root-v3"
SOURCE = "server_snapshot"
SNAPSHOT_VERSION = 2
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _evidence_digest(record: dict[str, Any]) -> str:
    material = "|".join(str(record.get(key)) for key in (
        "authority", "evidence_id", "lineage", "source", "release", "version", "check_id", "sequence", "expected_digest", "observed_digest"
    ))
    return hashlib.sha256(material.encode()).hexdigest()


def _aggregate(records: list[dict[str, Any]]) -> str:
    material = "\n".join(f"{r.get('order')}|{r.get('check_id')}|{r.get('evidence_digest')}" for r in records)
    return hashlib.sha256(material.encode()).hexdigest()


def validate_snapshot(report: Any, label: str = "snapshot") -> list[str]:
    """Return errors for evidence/lineage snapshot evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION, "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE, "policy_version": POLICY_VERSION,
        "authority": AUTHORITY, "evidence_id": EVIDENCE_ID, "lineage": LINEAGE,
        "source": SOURCE, "snapshot_version": SNAPSHOT_VERSION, "release": RELEASE_ID,
    }
    for key, value in expected.items():
        if report.get(key) != value:
            errors.append(f"{label}.{key} must be {value}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    snapshot = report.get("snapshot")
    if not isinstance(snapshot, dict):
        errors.append(f"{label}.snapshot must be an object")
        snapshot = {}
    for key, value in (("authority", AUTHORITY), ("evidence_id", report.get("evidence_id")), ("lineage", report.get("lineage")), ("source", report.get("source")), ("release", report.get("release")), ("version", report.get("snapshot_version"))):
        if snapshot.get(key) != value:
            errors.append(f"{label}.snapshot.{key} must match evidence/lineage")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    records = report.get("records")
    if not isinstance(records, list):
        errors.append(f"{label}.records must be an array")
        records = []
    ids: set[str] = set()
    evidenced = mutations = 0
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if record.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        record_id = record.get("check_id")
        if not isinstance(record_id, str) or not record_id:
            errors.append(f"{prefix}.check_id must be non-empty")
        elif record_id in ids:
            errors.append(f"{prefix}.check_id must be unique")
        else:
            ids.add(record_id)
        for key, value in (("authority", AUTHORITY), ("evidence_id", report.get("evidence_id")), ("lineage", report.get("lineage")), ("source", report.get("source")), ("release", report.get("release")), ("version", report.get("snapshot_version"))):
            if record.get(key) != value:
                errors.append(f"{prefix}.{key} must match evidence/lineage")
        if record.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        expected_digest = record.get("expected_digest")
        observed_digest = record.get("observed_digest")
        if not _digest(expected_digest) or not _digest(observed_digest):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif expected_digest != observed_digest:
            errors.append(f"{prefix}.observed_digest must match expected digest")
        evidence_digest = record.get("evidence_digest")
        if not _digest(evidence_digest):
            errors.append(f"{prefix}.evidence_digest must be lowercase SHA-256")
        elif evidence_digest != _evidence_digest(record):
            errors.append(f"{prefix}.evidence_digest must bind evidence/lineage")
        if record.get("evidenced") is not True:
            errors.append(f"{prefix}.evidenced must be true")
        else:
            evidenced += 1
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")

    aggregate_digest = report.get("aggregate_digest")
    if not _digest(aggregate_digest):
        errors.append(f"{label}.aggregate_digest must be lowercase SHA-256")
    elif aggregate_digest != _aggregate(records):
        errors.append(f"{label}.aggregate_digest must match evidence records")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"records": len(records), "unique": len(ids), "evidenced": evidenced, "mutations": mutations}
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match evidence records")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_snapshot_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_snapshot(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    args = parser.parse_args()
    errors = validate_snapshot_file(args.snapshot)
    if errors:
        print("NETWORK_SNAPSHOT_EVIDENCE_LINEAGE_V98_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_EVIDENCE_LINEAGE_V98_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
