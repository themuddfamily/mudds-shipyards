#!/usr/bin/env python3
"""Validate detached v54 snapshot release/version reconciliation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 54
EVIDENCE_SCOPE = "network_snapshot_release_version_reconciliation_v54"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SNAPSHOT_VERSION = 2
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _check_summary(check: dict[str, Any]) -> str:
    material = "|".join(str(check.get(key)) for key in (
        "authority", "release", "version", "check_id", "sequence", "expected_digest", "observed_digest"
    ))
    return hashlib.sha256(material.encode()).hexdigest()


def _summary(checks: list[dict[str, Any]]) -> str:
    material = "\n".join(
        f"{check.get('order')}|{check.get('check_id')}|{check.get('summary_digest')}"
        for check in checks
    )
    return hashlib.sha256(material.encode()).hexdigest()


def validate_checks(report: Any, label: str = "checks") -> list[str]:
    """Return errors for release/version-bound reconciliation evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION, "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE, "policy_version": POLICY_VERSION,
        "authority": AUTHORITY, "snapshot_version": SNAPSHOT_VERSION, "release": RELEASE_ID,
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
    if snapshot.get("authority") != AUTHORITY:
        errors.append(f"{label}.snapshot.authority must be {AUTHORITY}")
    if snapshot.get("release") != report.get("release"):
        errors.append(f"{label}.snapshot.release must match release")
    if snapshot.get("version") != report.get("snapshot_version"):
        errors.append(f"{label}.snapshot.version must match snapshot version")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    checks = report.get("checks")
    if not isinstance(checks, list):
        errors.append(f"{label}.checks must be an array")
        checks = []
    ids: set[str] = set()
    reconciled = mutations = 0
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
        if check.get("release") != report.get("release"):
            errors.append(f"{prefix}.release must match release")
        if check.get("version") != report.get("snapshot_version"):
            errors.append(f"{prefix}.version must match snapshot version")
        if check.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        expected_digest = check.get("expected_digest")
        observed_digest = check.get("observed_digest")
        if not _digest(expected_digest) or not _digest(observed_digest):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif expected_digest != observed_digest:
            errors.append(f"{prefix}.observed_digest must match expected digest")
        summary_digest = check.get("summary_digest")
        if not _digest(summary_digest):
            errors.append(f"{prefix}.summary_digest must be lowercase SHA-256")
        elif summary_digest != _check_summary(check):
            errors.append(f"{prefix}.summary_digest must bind release/version")
        if check.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled += 1
        if check.get("mutation_fields") != [] or check.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")

    summary_digest = report.get("summary_digest")
    if not _digest(summary_digest):
        errors.append(f"{label}.summary_digest must be lowercase SHA-256")
    elif summary_digest != _summary(checks):
        errors.append(f"{label}.summary_digest must match reconciliation checks")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"checks": len(checks), "unique": len(ids), "reconciled": reconciled, "mutations": mutations}
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match reconciliation checks")
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
        print("NETWORK_SNAPSHOT_RELEASE_VERSION_RECONCILIATION_V54_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_RELEASE_VERSION_RECONCILIATION_V54_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
