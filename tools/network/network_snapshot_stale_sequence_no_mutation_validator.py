#!/usr/bin/env python3
"""Validate detached stale snapshot-sequence no-mutation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_snapshot_stale_sequence_no_mutation"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED = {"duplicate", "lower", "out_of_order"}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_sequence(report: Any, label: str = "sequence") -> list[str]:
    """Return sequence-only stale rejection and state equality errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE), ("policy_version", POLICY_VERSION)):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    current = report.get("current")
    if not isinstance(current, dict):
        errors.append(f"{label}.current must be an object")
        current = {}
    if not _positive_int(current.get("sequence")) or not _positive_int(current.get("peer_generation")):
        errors.append(f"{label}.current sequence and peer_generation must be positive")
    if not isinstance(current.get("digest"), str) or not SHA256.fullmatch(current.get("digest", "")):
        errors.append(f"{label}.current.digest must be lowercase SHA-256")
    attempts = report.get("attempts")
    seen: set[str] = set()
    if not isinstance(attempts, list):
        errors.append(f"{label}.attempts must be an array")
        attempts = []
    for index, attempt in enumerate(attempts):
        prefix = f"{label}.attempts[{index}]"
        if not isinstance(attempt, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = attempt.get("kind")
        if kind not in REQUIRED:
            errors.append(f"{prefix}.kind is not a required sequence attempt")
        else:
            seen.add(kind)
        sequence = attempt.get("attempted_sequence")
        if not isinstance(sequence, int) or isinstance(sequence, bool) or sequence > current.get("sequence", 0) or (kind != "duplicate" and sequence >= current.get("sequence", 0)):
            errors.append(f"{prefix}.attempted_sequence must be stale")
        if attempt.get("accepted") is not False or attempt.get("status") != "stale_snapshot_sequence" or attempt.get("server_rejected") is not True:
            errors.append(f"{prefix} must be stale_snapshot_sequence rejected")
        if attempt.get("state_changed") is not False or attempt.get("mutation_fields") != []:
            errors.append(f"{prefix} must have no state or field mutation")
        if attempt.get("after_sequence") != current.get("sequence") or attempt.get("after_digest") != current.get("digest") or attempt.get("after_peer_generation") != current.get("peer_generation"):
            errors.append(f"{prefix} must preserve current snapshot state")
    for kind in sorted(REQUIRED - seen):
        errors.append(f"{label}.attempts must include {kind}")
    accepted = report.get("accepted_next")
    if not isinstance(accepted, dict) or accepted.get("accepted") is not True or accepted.get("sequence") != current.get("sequence", 0) + 1 or accepted.get("server_committed") is not True:
        errors.append(f"{label}.accepted_next must advance once server-side")
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    return errors


def validate_sequence_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_sequence(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sequence", type=Path)
    args = parser.parse_args()
    errors = validate_sequence_file(args.sequence)
    if errors:
        print("NETWORK_SNAPSHOT_STALE_SEQUENCE_NO_MUTATION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_STALE_SEQUENCE_NO_MUTATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
