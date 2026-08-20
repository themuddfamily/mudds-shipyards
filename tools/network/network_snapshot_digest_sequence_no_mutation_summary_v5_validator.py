#!/usr/bin/env python3
"""Validate v5 ordered snapshot digest/sequence no-mutation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 5
EVIDENCE_SCOPE = "network_snapshot_digest_sequence_no_mutation_summary_v5"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
KINDS = {"accepted", "stale_digest", "stale_sequence"}


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return v5 metadata, ordering, state-transition, count, and mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    initial = report.get("initial")
    final = report.get("final")
    states: dict[str, dict[str, Any]] = {}
    for name, state in (("initial", initial), ("final", final)):
        if not isinstance(state, dict):
            errors.append(f"{label}.{name} must be an object")
            continue
        states[name] = state
        if not _non_negative_int(state.get("sequence")):
            errors.append(f"{label}.{name}.sequence must be non-negative")
        if not _digest(state.get("digest")):
            errors.append(f"{label}.{name}.digest must be lowercase SHA-256")

    records = report.get("records")
    if not isinstance(records, list):
        errors.append(f"{label}.records must be an array")
        records = []
    counts = {"accepted": 0, "stale_digest": 0, "stale_sequence": 0}
    mutation_count = 0
    current = dict(states.get("initial", {}))
    current_sequence = current.get("sequence")
    current_digest = current.get("digest")
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if record.get("ordinal") != index + 1:
            errors.append(f"{prefix}.ordinal must be {index + 1}")
        kind = record.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind must be accepted, stale_digest, or stale_sequence")
            kind = None
        else:
            counts[kind] += 1
        sequence = record.get("sequence")
        digest = record.get("digest")
        if not _non_negative_int(sequence):
            errors.append(f"{prefix}.sequence must be non-negative")
        if not _digest(digest):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if kind == "accepted":
            if record.get("accepted") is not True:
                errors.append(f"{prefix}.accepted must be true")
            if _non_negative_int(current_sequence) and sequence != current_sequence + 1:
                errors.append(f"{prefix}.sequence must advance once from current state")
            if _digest(current_digest) and digest == current_digest:
                errors.append(f"{prefix}.digest must change on accepted update")
            current_sequence, current_digest = sequence, digest
        elif kind == "stale_digest":
            if record.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if sequence != current_sequence:
                errors.append(f"{prefix}.sequence must match current state")
            if _digest(current_digest) and digest == current_digest:
                errors.append(f"{prefix}.digest must be stale relative to current state")
        elif kind == "stale_sequence":
            if record.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if not _non_negative_int(current_sequence) or not _non_negative_int(sequence) or sequence >= current_sequence:
                errors.append(f"{prefix}.sequence must be older than current state")
        if record.get("after_sequence") != current_sequence or record.get("after_digest") != current_digest:
            errors.append(f"{prefix} must preserve or publish the expected state")
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    if states.get("final", {}).get("sequence") != current_sequence or states.get("final", {}).get("digest") != current_digest:
        errors.append(f"{label}.final must match ordered record state")

    summary = report.get("summary")
    if not isinstance(summary, dict):
        errors.append(f"{label}.summary must be an object")
    else:
        expected = {
            "total": len(records),
            "accepted": counts["accepted"],
            "stale_digest": counts["stale_digest"],
            "stale_sequence": counts["stale_sequence"],
            "rejected": counts["stale_digest"] + counts["stale_sequence"],
            "mutations": mutation_count,
        }
        for key, value in expected.items():
            if summary.get(key) != value:
                errors.append(f"{label}.summary.{key} must match ordered record counts")
        if summary.get("mutations") != 0:
            errors.append(f"{label}.summary.mutations must be zero")
    return errors


def validate_summary_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_summary(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args()
    errors = validate_summary_file(args.summary)
    if errors:
        print("NETWORK_SNAPSHOT_DIGEST_SEQUENCE_NO_MUTATION_SUMMARY_V5_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_SEQUENCE_NO_MUTATION_SUMMARY_V5_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
