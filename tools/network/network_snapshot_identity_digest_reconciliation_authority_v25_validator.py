#!/usr/bin/env python3
"""Validate v25 snapshot identity/digest reconciliation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 25
EVIDENCE_SCOPE = "network_snapshot_identity_digest_reconciliation_authority_v25"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _identity_digest(snapshot: dict[str, Any], identity: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{identity.get('identity_id')}|{snapshot.get('sequence')}|{identity.get('observed_digest')}".encode("utf-8")).hexdigest()


def validate_reconciliation(report: Any, label: str = "reconciliation") -> list[str]:
    """Return identity/digest agreement, count, and no-mutation errors."""

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
    if not isinstance(snapshot, dict):
        errors.append(f"{label}.snapshot must be an object")
        snapshot = {}
    if snapshot.get("authority") != AUTHORITY:
        errors.append(f"{label}.snapshot.authority must be {AUTHORITY}")
    if not _sequence(snapshot.get("sequence")):
        errors.append(f"{label}.snapshot.sequence must be non-negative")
    if not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot.digest must be lowercase SHA-256")

    identities = report.get("identities")
    if not isinstance(identities, list):
        errors.append(f"{label}.identities must be an array")
        identities = []
    ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, identity in enumerate(identities):
        prefix = f"{label}.identities[{index}]"
        if not isinstance(identity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if identity.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        identity_id = identity.get("identity_id")
        if not isinstance(identity_id, str) or not identity_id:
            errors.append(f"{prefix}.identity_id must be non-empty")
        elif identity_id in ids:
            errors.append(f"{prefix}.identity_id must be unique")
        else:
            ids.add(identity_id)
        if identity.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if identity.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        if not _digest(identity.get("expected_digest")) or not _digest(identity.get("observed_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif identity.get("expected_digest") != identity.get("observed_digest"):
            errors.append(f"{prefix}.observed_digest must match expected digest")
        identity_digest = identity.get("identity_digest")
        if not _digest(identity_digest):
            errors.append(f"{prefix}.identity_digest must be lowercase SHA-256")
        elif identity_digest != _identity_digest(snapshot, identity):
            errors.append(f"{prefix}.identity_digest must bind identity digest")
        if identity.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if identity.get("mutation_fields") != [] or identity.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"identities": len(identities), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match identity reconciliation")
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
        print("NETWORK_SNAPSHOT_IDENTITY_DIGEST_RECONCILIATION_AUTHORITY_V25_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_IDENTITY_DIGEST_RECONCILIATION_AUTHORITY_V25_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
