#!/usr/bin/env python3
"""Validate no-mutation evidence for stale snapshot attempts."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_snapshot_stale_no_mutation"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED = {"stale_snapshot_digest", "stale_snapshot_sequence", "stale_peer_generation"}
STATE_KEYS = ("peer_generation", "server_tick", "snapshot_sequence", "partition_digest", "visible_ids", "deferred_ids")


def _state(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return {}
    for key in STATE_KEYS:
        if key not in value:
            errors.append(f"{label}.{key} is required")
    if not isinstance(value.get("partition_digest"), str) or not SHA256.fullmatch(value.get("partition_digest", "")):
        errors.append(f"{label}.partition_digest must be lowercase SHA-256")
    for key in ("peer_generation", "server_tick", "snapshot_sequence"):
        if not isinstance(value.get(key), int) or isinstance(value.get(key), bool) or value[key] < 0:
            errors.append(f"{label}.{key} must be non-negative")
    for key in ("visible_ids", "deferred_ids"):
        if not isinstance(value.get(key), list) or any(not isinstance(item, str) for item in value.get(key, [])):
            errors.append(f"{label}.{key} must be an array of strings")
    return value


def validate_ledger(report: Any, label: str = "ledger") -> list[str]:
    """Return full-state equality and stale rejection errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE), ("policy_version", POLICY_VERSION)):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    before = _state(report.get("before"), f"{label}.before", errors)
    after = _state(report.get("after"), f"{label}.after", errors)
    if before and after and before != after:
        errors.append(f"{label}.after must equal before for stale no-mutation evidence")

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
        status = attempt.get("status")
        if status not in REQUIRED:
            errors.append(f"{prefix}.status is not a required stale attempt")
        else:
            seen.add(status)
        if attempt.get("accepted") is not False or attempt.get("server_rejected") is not True:
            errors.append(f"{prefix} must be server-rejected")
        if attempt.get("state_changed") is not False:
            errors.append(f"{prefix}.state_changed must be false")
        fields = attempt.get("mutation_fields")
        if fields != []:
            errors.append(f"{prefix}.mutation_fields must be empty")
        if attempt.get("after_state") != after:
            errors.append(f"{prefix}.after_state must equal final unchanged state")
    for status in sorted(REQUIRED - seen):
        errors.append(f"{label}.attempts must include {status}")
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
        print("NETWORK_SNAPSHOT_STALE_NO_MUTATION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_STALE_NO_MUTATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
