#!/usr/bin/env python3
"""Validate v38 snapshot authority/reconciliation digest checks."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 38
EVIDENCE_SCOPE = "network_snapshot_authority_reconciliation_digest_v38"
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


def _authority_check_digest(check: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{check.get('check_id')}|{check.get('sequence')}|{check.get('source_digest')}|{check.get('target_digest')}".encode("utf-8")).hexdigest()


def _aggregate_digest(checks: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{check.get('order')}|{check.get('check_id')}|{check.get('authority_check_digest')}" for check in checks).encode("utf-8")).hexdigest()


def validate_checks(report: Any, label: str = "checks") -> list[str]:
    """Return state, authority check digest, aggregate, count, and mutation errors."""

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

    snapshot = report.get("snapshot")
    reconciled = report.get("reconciled")
    for name, state in (("snapshot", snapshot), ("reconciled", reconciled)):
        if not _state(state):
            errors.append(f"{label}.{name} must contain sequence and lowercase SHA-256 digest")
        elif state.get("authority") != AUTHORITY:
            errors.append(f"{label}.{name}.authority must be {AUTHORITY}")
    if _state(snapshot) and _state(reconciled) and snapshot != reconciled:
        errors.append(f"{label}.reconciled must equal snapshot")

    checks = report.get("authority_checks")
    if not isinstance(checks, list):
        errors.append(f"{label}.authority_checks must be an array")
        checks = []
    ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, check in enumerate(checks):
        prefix = f"{label}.authority_checks[{index}]"
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
        if not _sequence(check.get("sequence")):
            errors.append(f"{prefix}.sequence must be non-negative")
        if not _digest(check.get("source_digest")) or not _digest(check.get("target_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif check.get("source_digest") != check.get("target_digest"):
            errors.append(f"{prefix}.target_digest must match source digest")
        authority_check_digest = check.get("authority_check_digest")
        if not _digest(authority_check_digest):
            errors.append(f"{prefix}.authority_check_digest must be lowercase SHA-256")
        elif authority_check_digest != _authority_check_digest(check):
            errors.append(f"{prefix}.authority_check_digest must bind authority check")
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
    elif aggregate_digest != _aggregate_digest(checks):
        errors.append(f"{label}.aggregate_digest must match authority checks")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"checks": len(checks), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority checks")
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
        print("NETWORK_SNAPSHOT_AUTHORITY_RECONCILIATION_DIGEST_V38_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_RECONCILIATION_DIGEST_V38_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
