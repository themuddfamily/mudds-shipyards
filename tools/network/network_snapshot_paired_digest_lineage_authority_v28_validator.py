#!/usr/bin/env python3
"""Validate v28 paired-digest lineage authority evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 28
EVIDENCE_SCOPE = "network_snapshot_paired_digest_lineage_authority_v28"
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


def _lineage_digest(pairs: list[dict[str, Any]]) -> str:
    payload = "\n".join(f"{pair.get('order')}|{pair.get('lineage_id')}|{pair.get('left_digest')}|{pair.get('right_digest')}" for pair in pairs)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_lineage(report: Any, label: str = "lineage") -> list[str]:
    """Return paired state, lineage identity, digest, count, and mutation errors."""

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

    left = report.get("left_state")
    right = report.get("right_state")
    for name, state in (("left_state", left), ("right_state", right)):
        if not _state(state):
            errors.append(f"{label}.{name} must contain sequence and lowercase SHA-256 digest")
        elif state.get("authority") != AUTHORITY:
            errors.append(f"{label}.{name}.authority must be {AUTHORITY}")
    if _state(left) and _state(right) and left != right:
        errors.append(f"{label}.right_state must equal left_state")

    pairs = report.get("pairs")
    if not isinstance(pairs, list):
        errors.append(f"{label}.pairs must be an array")
        pairs = []
    lineage_ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, pair in enumerate(pairs):
        prefix = f"{label}.pairs[{index}]"
        if not isinstance(pair, dict):
            errors.append(f"{prefix} must be an object")
            continue
        order = index + 1
        if pair.get("order") != order:
            errors.append(f"{prefix}.order must be {order}")
        pair_id = pair.get("pair_id")
        lineage_id = pair.get("lineage_id")
        expected_lineage = f"{AUTHORITY}|{pair_id}|{order}"
        if lineage_id != expected_lineage:
            errors.append(f"{prefix}.lineage_id must be {expected_lineage}")
        if not isinstance(lineage_id, str) or lineage_id in lineage_ids:
            errors.append(f"{prefix}.lineage_id must be unique")
        elif isinstance(lineage_id, str):
            lineage_ids.add(lineage_id)
        if pair.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if not _digest(pair.get("left_digest")) or not _digest(pair.get("right_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif pair.get("left_digest") != pair.get("right_digest"):
            errors.append(f"{prefix}.right_digest must match left digest")
        if pair.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if pair.get("mutation_fields") != [] or pair.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    lineage_digest = report.get("lineage_digest")
    if not _digest(lineage_digest):
        errors.append(f"{label}.lineage_digest must be lowercase SHA-256")
    elif lineage_digest != _lineage_digest(pairs):
        errors.append(f"{label}.lineage_digest must match paired lineage")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"pairs": len(pairs), "unique": len(lineage_ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match paired lineage")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_lineage_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_lineage(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lineage", type=Path)
    args = parser.parse_args()
    errors = validate_lineage_file(args.lineage)
    if errors:
        print("NETWORK_SNAPSHOT_PAIRED_DIGEST_LINEAGE_AUTHORITY_V28_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_PAIRED_DIGEST_LINEAGE_AUTHORITY_V28_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
