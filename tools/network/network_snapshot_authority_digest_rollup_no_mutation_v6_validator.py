#!/usr/bin/env python3
"""Validate v6 authority-scoped snapshot digest rollup evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 6
EVIDENCE_SCOPE = "network_snapshot_authority_digest_rollup_no_mutation_v6"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
DECISIONS = {"accepted", "rejected_digest", "rejected_sequence"}


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def validate_rollup(report: Any, label: str = "rollup") -> list[str]:
    """Return authority, order, count, state, and mutation-boundary errors."""

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

    initial = report.get("initial")
    final = report.get("final")
    states: dict[str, dict[str, Any]] = {}
    for name, state in (("initial", initial), ("final", final)):
        if not isinstance(state, dict):
            errors.append(f"{label}.{name} must be an object")
            continue
        states[name] = state
        if not _sequence(state.get("sequence")):
            errors.append(f"{label}.{name}.sequence must be non-negative")
        if not _digest(state.get("digest")):
            errors.append(f"{label}.{name}.digest must be lowercase SHA-256")

    events = report.get("events")
    if not isinstance(events, list):
        errors.append(f"{label}.events must be an array")
        events = []
    counts = {decision: 0 for decision in DECISIONS}
    mutation_count = 0
    current = dict(states.get("initial", {}))
    for index, event in enumerate(events):
        prefix = f"{label}.events[{index}]"
        if not isinstance(event, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if event.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if event.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        decision = event.get("decision")
        if decision not in DECISIONS:
            errors.append(f"{prefix}.decision must be accepted, rejected_digest, or rejected_sequence")
        else:
            counts[decision] += 1
        sequence = event.get("sequence")
        digest = event.get("digest")
        if not _sequence(sequence):
            errors.append(f"{prefix}.sequence must be non-negative")
        if not _digest(digest):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if decision == "accepted":
            if event.get("accepted") is not True:
                errors.append(f"{prefix}.accepted must be true")
            if _sequence(current.get("sequence")) and sequence != current["sequence"] + 1:
                errors.append(f"{prefix}.sequence must advance once from current authority state")
            current = {"sequence": sequence, "digest": digest}
        elif decision == "rejected_digest":
            if event.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if sequence != current.get("sequence"):
                errors.append(f"{prefix}.sequence must match current authority state")
            if _digest(current.get("digest")) and digest == current["digest"]:
                errors.append(f"{prefix}.digest must differ from current authority digest")
        elif decision == "rejected_sequence":
            if event.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if not _sequence(current.get("sequence")) or not _sequence(sequence) or sequence >= current["sequence"]:
                errors.append(f"{prefix}.sequence must be older than current authority state")
        after = event.get("after")
        if not isinstance(after, dict):
            errors.append(f"{prefix}.after must be an object")
        elif after.get("sequence") != current.get("sequence") or after.get("digest") != current.get("digest"):
            errors.append(f"{prefix}.after must match the authority state")
        if event.get("mutation_fields") != [] or event.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    if states.get("final", {}) != current:
        errors.append(f"{label}.final must match ordered authority state")

    counts_report = report.get("counts")
    if not isinstance(counts_report, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {
            "events": len(events),
            "accepted": counts["accepted"],
            "rejected_digest": counts["rejected_digest"],
            "rejected_sequence": counts["rejected_sequence"],
            "rejected": counts["rejected_digest"] + counts["rejected_sequence"],
            "mutations": mutation_count,
        }
        for key, value in expected.items():
            if counts_report.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority event counts")
        if counts_report.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_rollup_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_rollup(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    args = parser.parse_args()
    errors = validate_rollup_file(args.rollup)
    if errors:
        print("NETWORK_SNAPSHOT_AUTHORITY_DIGEST_ROLLUP_NO_MUTATION_V6_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_DIGEST_ROLLUP_NO_MUTATION_V6_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
