#!/usr/bin/env python3
"""Validate v50 versioned authority/reconciliation checks."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 50
EVIDENCE_SCOPE = "network_snapshot_versioned_authority_reconciliation_v50"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SNAPSHOT_VERSION = 2
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _check_digest(check: dict[str, Any]) -> str:
    return hashlib.sha256(f"{check.get('authority')}|{check.get('version')}|{check.get('check_id')}|{check.get('expected_digest')}|{check.get('observed_digest')}".encode("utf-8")).hexdigest()


def _aggregate(checks: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{check.get('order')}|{check.get('check_id')}|{check.get('authority_digest')}" for check in checks).encode("utf-8")).hexdigest()


def validate_checks(report: Any, label: str = "checks") -> list[str]:
    """Return versioned check bindings, aggregate, count, and mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE), ("policy_version", POLICY_VERSION), ("authority", AUTHORITY), ("snapshot_version", SNAPSHOT_VERSION)):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")
    snapshot = report.get("snapshot")
    if not isinstance(snapshot, dict) or not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")
        snapshot = {}
    elif snapshot.get("authority") != AUTHORITY or snapshot.get("version") != SNAPSHOT_VERSION:
        errors.append(f"{label}.snapshot authority/version must match contract")

    checks = report.get("checks")
    if not isinstance(checks, list):
        errors.append(f"{label}.checks must be an array")
        checks = []
    ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, check in enumerate(checks):
        prefix = f"{label}.checks[{index}]"
        if not isinstance(check, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if check.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        check_id = check.get("check_id")
        if not isinstance(check_id, str) or not check_id:
            errors.append(f"{prefix}.check_id must be non-empty")
        elif check_id in ids:
            errors.append(f"{prefix}.check_id must be unique")
        else:
            ids.add(check_id)
        if check.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if check.get("version") != SNAPSHOT_VERSION:
            errors.append(f"{prefix}.version must be {SNAPSHOT_VERSION}")
        if check.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        if not _digest(check.get("expected_digest")) or not _digest(check.get("observed_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif check.get("expected_digest") != check.get("observed_digest"):
            errors.append(f"{prefix}.observed_digest must match expected digest")
        authority_digest = check.get("authority_digest")
        if not _digest(authority_digest):
            errors.append(f"{prefix}.authority_digest must be lowercase SHA-256")
        elif authority_digest != _check_digest(check):
            errors.append(f"{prefix}.authority_digest must bind versioned check")
        if check.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if check.get("mutation_fields") != [] or check.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    aggregate_digest = report.get("aggregate_digest")
    if not _digest(aggregate_digest):
        errors.append(f"{label}.aggregate_digest must be lowercase SHA-256")
    elif aggregate_digest != _aggregate(checks):
        errors.append(f"{label}.aggregate_digest must match versioned checks")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"checks": len(checks), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match versioned checks")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_checks_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_checks(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checks", type=Path)
    args = parser.parse_args()
    errors = validate_checks_file(args.checks)
    if errors:
        print("NETWORK_SNAPSHOT_VERSIONED_AUTHORITY_RECONCILIATION_V50_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_VERSIONED_AUTHORITY_RECONCILIATION_V50_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
