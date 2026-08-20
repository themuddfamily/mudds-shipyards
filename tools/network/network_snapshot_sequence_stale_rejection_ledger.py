#!/usr/bin/env python3
"""Validate detached stale snapshot-sequence rejection evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_snapshot_sequence_stale_rejection"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED = {"duplicate_snapshot_sequence", "lower_snapshot_sequence", "out_of_order_snapshot_sequence"}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_ledger(report: Any, label: str = "ledger") -> list[str]:
    """Return sequence rejection and no-mutation errors."""

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
    if not _positive_int(current.get("sequence")):
        errors.append(f"{label}.current.sequence must be positive")
    if not isinstance(current.get("digest"), str) or not SHA256.fullmatch(current["digest"]):
        errors.append(f"{label}.current.digest must be lowercase SHA-256")
    if not _positive_int(current.get("peer_generation")):
        errors.append(f"{label}.current.peer_generation must be positive")

    attempts = report.get("rejections")
    seen: set[str] = set()
    if not isinstance(attempts, list):
        errors.append(f"{label}.rejections must be an array")
        attempts = []
    for index, attempt in enumerate(attempts):
        prefix = f"{label}.rejections[{index}]"
        if not isinstance(attempt, dict):
            errors.append(f"{prefix} must be an object")
            continue
        status = attempt.get("status")
        if status not in REQUIRED:
            errors.append(f"{prefix}.status is not a required sequence rejection")
        else:
            seen.add(status)
        if attempt.get("accepted") is not False or attempt.get("server_rejected") is not True:
            errors.append(f"{prefix} must be server-rejected")
        if not isinstance(attempt.get("attempted_sequence"), int) or isinstance(attempt.get("attempted_sequence"), bool) or attempt["attempted_sequence"] > current.get("sequence", 0) or (status != "duplicate_snapshot_sequence" and attempt["attempted_sequence"] >= current.get("sequence", 0)):
            errors.append(f"{prefix}.attempted_sequence must be stale relative to current")
        if attempt.get("current_sequence") != current.get("sequence") or attempt.get("current_digest") != current.get("digest") or attempt.get("current_peer_generation") != current.get("peer_generation"):
            errors.append(f"{prefix} must preserve current sequence, digest, and generation")
        if attempt.get("state_changed") is not False or attempt.get("cursor_changed") is not False:
            errors.append(f"{prefix} must not change state or cursor")
    for status in sorted(REQUIRED - seen):
        errors.append(f"{label}.rejections must include {status}")

    accepted = report.get("accepted_next")
    if not isinstance(accepted, dict) or accepted.get("accepted") is not True or accepted.get("status") != "snapshot_accepted":
        errors.append(f"{label}.accepted_next must be snapshot_accepted")
    elif accepted.get("sequence") != current.get("sequence", 0) + 1 or accepted.get("server_committed") is not True:
        errors.append(f"{label}.accepted_next must advance once under server authority")
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    return errors


def validate_ledger_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_ledger(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args()
    errors = validate_ledger_file(args.ledger)
    if errors:
        print("NETWORK_SNAPSHOT_SEQUENCE_STALE_REJECTION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_SEQUENCE_STALE_REJECTION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
