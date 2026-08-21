#!/usr/bin/env python3
"""Validate detached v274 network snapshot authority-takeover seal evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 274
EVIDENCE_SCOPE = "network_snapshot_authority_takeover_seal_v274"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SEAL_ID = "server-authority-seal-v1"
TAKEOVER_TOKEN = "server-authority-takeover-token-v45"
SNAPSHOT_ID = "snapshot-authority-v157"
SOURCE = "server_snapshot"
SNAPSHOT_VERSION = 46
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
NOT_RUN_CHECKS = ("stale_check", "native_run", "hardware_run", "human_review")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _seal_digest(record: dict[str, Any]) -> str:
    fields = (
        "seal_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "checkpoint", "entry_id", "expected_digest", "observed_digest",
    )
    return hashlib.sha256("|".join(str(record.get(field)) for field in fields).encode()).hexdigest()


def _rollup_digest(records: list[dict[str, Any]]) -> str:
    material = "\n".join(
        f"{record.get('order')}|{record.get('entry_id')}|{record.get('seal_digest')}"
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
    """Return errors for detached authority-takeover seal evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION,
        "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE,
        "policy_version": POLICY_VERSION,
        "authority": AUTHORITY,
        "seal_id": SEAL_ID,
        "takeover_token": TAKEOVER_TOKEN,
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
    for key in NOT_RUN_CHECKS:
        _validate_not_run(report.get(key), f"{label}.{key}", errors)

    snapshot = report.get("snapshot")
    if not isinstance(snapshot, dict):
        errors.append(f"{label}.snapshot must be an object")
        snapshot = {}
    snapshot_fields = (
        ("seal_id", report.get("seal_id")),
        ("takeover_token", report.get("takeover_token")),
        ("snapshot_id", report.get("snapshot_id")),
        ("authority", AUTHORITY), ("source", report.get("source")),
        ("release", report.get("release")), ("version", report.get("snapshot_version")),
    )
    for key, value in snapshot_fields:
        if snapshot.get(key) != value:
            errors.append(f"{label}.snapshot.{key} must match authority seal")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    records = report.get("seal_entries")
    if not isinstance(records, list):
        errors.append(f"{label}.seal_entries must be an array")
        records = []
    ids: set[str] = set()
    sealed = mutations = 0
    for index, record in enumerate(records):
        prefix = f"{label}.seal_entries[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if record.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        entry_id = record.get("entry_id")
        if not isinstance(entry_id, str) or not entry_id:
            errors.append(f"{prefix}.entry_id must be non-empty")
        elif entry_id in ids:
            errors.append(f"{prefix}.entry_id must be unique")
        else:
            ids.add(entry_id)
        for key, value in (
            ("seal_id", report.get("seal_id")),
            ("takeover_token", report.get("takeover_token")),
            ("snapshot_id", report.get("snapshot_id")),
            ("authority", AUTHORITY),
        ):
            if record.get(key) != value:
                errors.append(f"{prefix}.{key} must match authority seal")
        if record.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        if not isinstance(record.get("checkpoint"), str) or not record["checkpoint"]:
            errors.append(f"{prefix}.checkpoint must be non-empty")
        expected_digest = record.get("expected_digest")
        observed_digest = record.get("observed_digest")
        if not _digest(expected_digest) or not _digest(observed_digest):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif expected_digest != observed_digest:
            errors.append(f"{prefix}.observed_digest must match expected digest")
        seal_digest = record.get("seal_digest")
        if not _digest(seal_digest):
            errors.append(f"{prefix}.seal_digest must be lowercase SHA-256")
        elif seal_digest != _seal_digest(record):
            errors.append(f"{prefix}.seal_digest must bind authority seal")
        if record.get("sealed") is not True:
            errors.append(f"{prefix}.sealed must be true")
        else:
            sealed += 1
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")

    rollup_digest = report.get("rollup_digest")
    if not _digest(rollup_digest):
        errors.append(f"{label}.rollup_digest must be lowercase SHA-256")
    elif rollup_digest != _rollup_digest(records):
        errors.append(f"{label}.rollup_digest must match authority seal entries")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {
            "entries": len(records), "unique": len(ids), "sealed": sealed, "mutations": mutations,
        }
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority seal entries")
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
        print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_SEAL_V274_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_SEAL_V274_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
