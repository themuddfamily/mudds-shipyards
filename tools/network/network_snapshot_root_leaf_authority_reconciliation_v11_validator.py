#!/usr/bin/env python3
"""Validate v11 root/leaf authority reconciliation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 11
EVIDENCE_SCOPE = "network_snapshot_root_leaf_authority_reconciliation_v11"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _authority_digest(root: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{root.get('sequence')}|{root.get('digest')}".encode("utf-8")).hexdigest()


def validate_reconciliation(report: Any, label: str = "reconciliation") -> list[str]:
    """Return root anchor, leaf agreement, count, and mutation-boundary errors."""

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

    root = report.get("root")
    if not isinstance(root, dict):
        errors.append(f"{label}.root must be an object")
        root = {}
    if root.get("authority") != AUTHORITY:
        errors.append(f"{label}.root.authority must be {AUTHORITY}")
    if not _sequence(root.get("sequence")):
        errors.append(f"{label}.root.sequence must be non-negative")
    if not _digest(root.get("digest")):
        errors.append(f"{label}.root.digest must be lowercase SHA-256")
    root_digest = root.get("authority_digest")
    if not _digest(root_digest):
        errors.append(f"{label}.root.authority_digest must be lowercase SHA-256")
    elif root_digest != _authority_digest(root):
        errors.append(f"{label}.root.authority_digest must anchor root authority state")

    leaves = report.get("leaves")
    if not isinstance(leaves, list):
        errors.append(f"{label}.leaves must be an array")
        leaves = []
    mutation_count = 0
    reconciled_count = 0
    leaf_ids: set[str] = set()
    for index, leaf in enumerate(leaves):
        prefix = f"{label}.leaves[{index}]"
        if not isinstance(leaf, dict):
            errors.append(f"{prefix} must be an object")
            continue
        leaf_id = leaf.get("leaf_id")
        if not isinstance(leaf_id, str) or not leaf_id:
            errors.append(f"{prefix}.leaf_id must be non-empty")
        elif leaf_id in leaf_ids:
            errors.append(f"{prefix}.leaf_id must be unique")
        else:
            leaf_ids.add(leaf_id)
        if leaf.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if leaf.get("root_digest") != root_digest:
            errors.append(f"{prefix}.root_digest must match root authority digest")
        if leaf.get("sequence") != root.get("sequence"):
            errors.append(f"{prefix}.sequence must match root sequence")
        if not _digest(leaf.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if leaf.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if leaf.get("mutation_fields") != [] or leaf.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"leaves": len(leaves), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match leaf reconciliation")
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
        print("NETWORK_SNAPSHOT_ROOT_LEAF_AUTHORITY_RECONCILIATION_V11_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_ROOT_LEAF_AUTHORITY_RECONCILIATION_V11_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
