#!/usr/bin/env python3
"""Validate v21 snapshot reconciliation digest authority evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 21
EVIDENCE_SCOPE = "network_snapshot_reconciliation_digest_authority_v21"
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


def _reconciliation_digest(checks: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{check.get('order')}|{check.get('check_id')}|{check.get('expected_digest')}|{check.get('observed_digest')}" for check in checks).encode("utf-8")).hexdigest()


def validate_reconciliation(report: Any, label: str = "reconciliation") -> list[str]:
    """Return state, check digest, count, and no-mutation errors."""

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
    if _state(before) and _state(after) and (before.get("sequence") != after.get("sequence") or before.get("digest") != after.get("digest")):
        errors.append(f"{label}.after must preserve before state")

    checks = report.get("checks")
    if not isinstance(checks, list):
        errors.append(f"{label}.checks must be an array")
        checks = []
    check_ids: set[str] = set()
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
        elif check_id in check_ids:
            errors.append(f"{prefix}.check_id must be unique")
        else:
            check_ids.add(check_id)
        if check.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if not _digest(check.get("expected_digest")):
            errors.append(f"{prefix}.expected_digest must be lowercase SHA-256")
        if not _digest(check.get("observed_digest")):
            errors.append(f"{prefix}.observed_digest must be lowercase SHA-256")
        elif check.get("observed_digest") != check.get("expected_digest"):
            errors.append(f"{prefix}.observed_digest must match expected digest")
        if check.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if check.get("mutation_fields") != [] or check.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    reconciliation_digest = report.get("reconciliation_digest")
    if not _digest(reconciliation_digest):
        errors.append(f"{label}.reconciliation_digest must be lowercase SHA-256")
    elif reconciliation_digest != _reconciliation_digest(checks):
        errors.append(f"{label}.reconciliation_digest must match ordered checks")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"checks": len(checks), "unique": len(check_ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match reconciliation checks")
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
        print("NETWORK_SNAPSHOT_RECONCILIATION_DIGEST_AUTHORITY_V21_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_RECONCILIATION_DIGEST_AUTHORITY_V21_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
