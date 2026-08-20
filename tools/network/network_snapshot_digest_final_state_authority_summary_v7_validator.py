#!/usr/bin/env python3
"""Validate v7 authority summary evidence for snapshot digest final state."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 7
EVIDENCE_SCOPE = "network_snapshot_digest_final_state_authority_summary_v7"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REJECTION_KINDS = {"stale_digest", "stale_sequence"}


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return final-state, authority, count, and mutation-boundary errors."""

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
    for name, state in (("initial", initial), ("final", final)):
        if not isinstance(state, dict):
            errors.append(f"{label}.{name} must be an object")
            continue
        if not _sequence(state.get("sequence")):
            errors.append(f"{label}.{name}.sequence must be non-negative")
        if not _digest(state.get("digest")):
            errors.append(f"{label}.{name}.digest must be lowercase SHA-256")

    accepted = report.get("accepted_update")
    if not isinstance(accepted, dict):
        errors.append(f"{label}.accepted_update must be an object")
        accepted = {}
    if accepted.get("authority") != AUTHORITY:
        errors.append(f"{label}.accepted_update.authority must be {AUTHORITY}")
    if accepted.get("accepted") is not True:
        errors.append(f"{label}.accepted_update.accepted must be true")
    if isinstance(initial, dict) and _sequence(initial.get("sequence")) and accepted.get("sequence") != initial["sequence"] + 1:
        errors.append(f"{label}.accepted_update.sequence must advance once")
    if isinstance(final, dict) and accepted.get("sequence") != final.get("sequence"):
        errors.append(f"{label}.accepted_update.sequence must match final state")
    if isinstance(final, dict) and accepted.get("digest") != final.get("digest"):
        errors.append(f"{label}.accepted_update.digest must match final state")
    if isinstance(initial, dict) and _digest(initial.get("digest")) and accepted.get("digest") == initial["digest"]:
        errors.append(f"{label}.accepted_update.digest must change from initial state")
    if accepted.get("mutation_fields") != [] or accepted.get("state_changed") is not False:
        errors.append(f"{label}.accepted_update must have no mutation")

    rejections = report.get("rejections")
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
        rejections = []
    rejection_counts = {kind: 0 for kind in REJECTION_KINDS}
    mutation_count = 0
    for index, rejection in enumerate(rejections):
        prefix = f"{label}.rejections[{index}]"
        if not isinstance(rejection, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if rejection.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if rejection.get("accepted") is not False:
            errors.append(f"{prefix}.accepted must be false")
        kind = rejection.get("kind")
        if kind not in REJECTION_KINDS:
            errors.append(f"{prefix}.kind must be stale_digest or stale_sequence")
        else:
            rejection_counts[kind] += 1
        if isinstance(final, dict):
            if rejection.get("after_sequence") != final.get("sequence") or rejection.get("after_digest") != final.get("digest"):
                errors.append(f"{prefix} must preserve final state")
        if rejection.get("mutation_fields") != [] or rejection.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    summary = report.get("summary")
    if not isinstance(summary, dict):
        errors.append(f"{label}.summary must be an object")
    else:
        expected = {
            "rejections": len(rejections),
            "stale_digest": rejection_counts["stale_digest"],
            "stale_sequence": rejection_counts["stale_sequence"],
            "mutations": mutation_count,
            "accepted_updates": 1,
        }
        for key, value in expected.items():
            if summary.get(key) != value:
                errors.append(f"{label}.summary.{key} must match final-state evidence")
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
        print("NETWORK_SNAPSHOT_DIGEST_FINAL_STATE_AUTHORITY_SUMMARY_V7_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_FINAL_STATE_AUTHORITY_SUMMARY_V7_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
