#!/usr/bin/env python3
"""Validate detached v150 network snapshot authority-challenge evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 150
EVIDENCE_SCOPE = "network_snapshot_authority_challenge_v150"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
AUTHORITY_CHALLENGE = "server-authority-challenge-v1"
SNAPSHOT_ID = "snapshot-authority-v33"
SOURCE = "server_snapshot"
SNAPSHOT_VERSION = 2
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _binding_digest(record: dict[str, Any]) -> str:
    fields = (
        "authority_challenge", "snapshot_id", "authority", "source", "release",
        "version", "check_id", "sequence", "expected_digest", "observed_digest",
    )
    return hashlib.sha256("|".join(str(record.get(key)) for key in fields).encode()).hexdigest()


def _aggregate(records: list[dict[str, Any]]) -> str:
    material = "\n".join(
        f"{record.get('order')}|{record.get('check_id')}|{record.get('binding_digest')}"
        for record in records
    )
    return hashlib.sha256(material.encode()).hexdigest()


def _validate_not_run(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object with NOT_RUN status")
        return
    if value.get("status") != "NOT_RUN":
        errors.append(f"{prefix}.status must remain NOT_RUN")
    if value.get("evidence") is not None:
        errors.append(f"{prefix}.evidence must be null when NOT_RUN")
    if not isinstance(value.get("reason"), str) or not value["reason"].strip():
        errors.append(f"{prefix}.reason is required when NOT_RUN")


def validate_snapshot(report: Any, label: str = "snapshot") -> list[str]:
    """Return errors for detached authority-challenge snapshot evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION,
        "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE,
        "policy_version": POLICY_VERSION,
        "authority": AUTHORITY,
        "authority_challenge": AUTHORITY_CHALLENGE,
        "snapshot_id": SNAPSHOT_ID,
        "source": SOURCE,
        "snapshot_version": SNAPSHOT_VERSION,
        "release": RELEASE_ID,
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
    _validate_not_run(report.get("stale_check"), f"{label}.stale_check", errors)
    _validate_not_run(report.get("native_run"), f"{label}.native_run", errors)

    snapshot = report.get("snapshot")
    if not isinstance(snapshot, dict):
        errors.append(f"{label}.snapshot must be an object")
        snapshot = {}
    snapshot_fields = (
        ("authority_challenge", report.get("authority_challenge")),
        ("snapshot_id", report.get("snapshot_id")),
        ("authority", AUTHORITY),
        ("source", report.get("source")),
        ("release", report.get("release")),
        ("version", report.get("snapshot_version")),
    )
    for key, value in snapshot_fields:
        if snapshot.get(key) != value:
            errors.append(f"{label}.snapshot.{key} must match authority challenge")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    records = report.get("records")
    if not isinstance(records, list):
        errors.append(f"{label}.records must be an array")
        records = []
    ids: set[str] = set()
    authorized = mutations = 0
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
        for key, value in snapshot_fields:
            if record.get(key) != value:
                errors.append(f"{prefix}.{key} must match authority challenge")
        if record.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        expected_digest = record.get("expected_digest")
        observed_digest = record.get("observed_digest")
        if not _digest(expected_digest) or not _digest(observed_digest):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif expected_digest != observed_digest:
            errors.append(f"{prefix}.observed_digest must match expected digest")
        binding_digest = record.get("binding_digest")
        if not _digest(binding_digest):
            errors.append(f"{prefix}.binding_digest must be lowercase SHA-256")
        elif binding_digest != _binding_digest(record):
            errors.append(f"{prefix}.binding_digest must bind authority challenge")
        if record.get("authorized") is not True:
            errors.append(f"{prefix}.authorized must be true")
        else:
            authorized += 1
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")

    aggregate_digest = report.get("aggregate_digest")
    if not _digest(aggregate_digest):
        errors.append(f"{label}.aggregate_digest must be lowercase SHA-256")
    elif aggregate_digest != _aggregate(records):
        errors.append(f"{label}.aggregate_digest must match authority challenge records")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {
            "records": len(records),
            "unique": len(ids),
            "authorized": authorized,
            "mutations": mutations,
        }
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority challenge records")
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
        print("NETWORK_SNAPSHOT_AUTHORITY_CHALLENGE_V150_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_CHALLENGE_V150_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
