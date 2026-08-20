#!/usr/bin/env python3
"""Validate v20 snapshot authority-binding reconciliation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 20
EVIDENCE_SCOPE = "network_snapshot_authority_binding_reconciliation_v20"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _binding_digest(binding_id: str, sequence: Any, snapshot_digest: str) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{binding_id}|{sequence}|{snapshot_digest}".encode("utf-8")).hexdigest()


def validate_reconciliation(report: Any, label: str = "reconciliation") -> list[str]:
    """Return expected/observed binding, digest, count, and mutation errors."""

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

    expected = report.get("expected_bindings")
    if not isinstance(expected, list):
        errors.append(f"{label}.expected_bindings must be an array")
        expected = []
    expected_map: dict[str, str] = {}
    for index, binding in enumerate(expected):
        prefix = f"{label}.expected_bindings[{index}]"
        if not isinstance(binding, dict):
            errors.append(f"{prefix} must be an object")
            continue
        binding_id = binding.get("binding_id")
        if not isinstance(binding_id, str) or not binding_id:
            errors.append(f"{prefix}.binding_id must be non-empty")
            continue
        if binding_id in expected_map:
            errors.append(f"{prefix}.binding_id must be unique")
        expected_map[binding_id] = binding.get("binding_digest", "")
        if binding.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if not _digest(binding.get("binding_digest")):
            errors.append(f"{prefix}.binding_digest must be lowercase SHA-256")

    observed = report.get("observed_bindings")
    if not isinstance(observed, list):
        errors.append(f"{label}.observed_bindings must be an array")
        observed = []
    observed_ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, binding in enumerate(observed):
        prefix = f"{label}.observed_bindings[{index}]"
        if not isinstance(binding, dict):
            errors.append(f"{prefix} must be an object")
            continue
        binding_id = binding.get("binding_id")
        if not isinstance(binding_id, str) or not binding_id:
            errors.append(f"{prefix}.binding_id must be non-empty")
        elif binding_id in observed_ids:
            errors.append(f"{prefix}.binding_id must be unique")
        else:
            observed_ids.add(binding_id)
        if binding.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if binding.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        if binding.get("snapshot_digest") != snapshot.get("digest"):
            errors.append(f"{prefix}.snapshot_digest must match snapshot")
        actual_digest = binding.get("binding_digest")
        if not _digest(actual_digest):
            errors.append(f"{prefix}.binding_digest must be lowercase SHA-256")
        elif isinstance(binding_id, str) and _digest(snapshot.get("digest")) and actual_digest != _binding_digest(binding_id, snapshot.get("sequence"), snapshot.get("digest")):
            errors.append(f"{prefix}.binding_digest must match authority binding")
        if binding_id not in expected_map or expected_map.get(binding_id) != actual_digest:
            errors.append(f"{prefix} must match an expected authority binding")
        if binding.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if binding.get("mutation_fields") != [] or binding.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
    if observed_ids != set(expected_map):
        errors.append(f"{label}.observed_bindings must exactly cover expected bindings")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"expected": len(expected), "observed": len(observed), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match binding reconciliation")
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
        print("NETWORK_SNAPSHOT_AUTHORITY_BINDING_RECONCILIATION_V20_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_BINDING_RECONCILIATION_V20_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
