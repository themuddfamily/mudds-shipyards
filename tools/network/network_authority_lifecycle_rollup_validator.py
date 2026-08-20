#!/usr/bin/env python3
"""Validate a detached multiplayer authority/interest/lifecycle rollup.

The rollup is a small evidence seam for the already-authored Godot ledgers. It
checks that one fixture covers admission, server-owned binding, interest
publication, replication, correction, and cleanup in that order. It does not
run a peer, measure a transport, or turn fixture output into native evidence.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_authority_interest_lifecycle"
EVIDENCE_MODE = "detached_contract_fixture"

_REQUIRED_POLICIES = {
    "admit": "network_session_handshake_v1",
    "bind": "network_disconnect_lifecycle_v1",
    "interest": "network_replication_interest_authority_v1",
    "replicate": "network_replication_interest_authority_v1",
    "correct": "network_prediction_correction_guard_v1",
    "cleanup": "network_disconnect_lifecycle_v1",
}
_REQUIRED_PHASES = tuple(_REQUIRED_POLICIES)


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_rollup(report: Any, label: str = "rollup") -> list[str]:
    """Return structural errors for a detached contract evidence rollup."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if report.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if report.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    if report.get("native_claims") is not False:
        errors.append(f"{label}.native_claims must be false for a detached fixture")

    fixture_id = report.get("fixture_id")
    if not isinstance(fixture_id, str) or not fixture_id.strip():
        errors.append(f"{label}.fixture_id must be non-empty")
    authority_peer_id = report.get("authority_peer_id")
    if not _non_negative_int(authority_peer_id) or authority_peer_id <= 0:
        errors.append(f"{label}.authority_peer_id must be a positive integer")

    phases = report.get("phases")
    if not isinstance(phases, list):
        errors.append(f"{label}.phases must be an array")
        return errors
    names = [phase.get("name") if isinstance(phase, dict) else None for phase in phases]
    if tuple(names) != _REQUIRED_PHASES:
        errors.append(f"{label}.phases must follow the required order: {', '.join(_REQUIRED_PHASES)}")

    seen: set[str] = set()
    for index, phase in enumerate(phases):
        prefix = f"{label}.phases[{index}]"
        if not isinstance(phase, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = phase.get("name")
        if name not in _REQUIRED_POLICIES:
            errors.append(f"{prefix}.name is not a required lifecycle phase")
        elif name in seen:
            errors.append(f"{prefix}.name must be unique")
        else:
            seen.add(name)
            expected_policy = _REQUIRED_POLICIES[name]
            if phase.get("policy_version") != expected_policy:
                errors.append(f"{prefix}.policy_version must be {expected_policy}")
        if phase.get("accepted") is not True:
            errors.append(f"{prefix}.accepted must be true")
        if phase.get("server_authority") is not True:
            errors.append(f"{prefix}.server_authority must be true")
        if not _non_negative_int(phase.get("event_sequence")):
            errors.append(f"{prefix}.event_sequence must be a non-negative integer")
        if phase.get("source") not in {"server", "server_adapter"}:
            errors.append(f"{prefix}.source must be server or server_adapter")
        if name == "correct" and phase.get("client_can_mutate_state") is not False:
            errors.append(f"{prefix}.client_can_mutate_state must be false")
        if name == "cleanup" and phase.get("active_after") is not False:
            errors.append(f"{prefix}.active_after must be false")

    sequences = [
        phase.get("event_sequence")
        for phase in phases
        if isinstance(phase, dict) and _non_negative_int(phase.get("event_sequence"))
    ]
    if sequences != sorted(set(sequences)):
        errors.append(f"{label}.phases.event_sequence must be strictly increasing")
    return errors


def validate_rollup_file(report_path: Path) -> list[str]:
    """Load and validate one JSON rollup file."""

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
        print("NETWORK_AUTHORITY_LIFECYCLE_ROLLUP_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_AUTHORITY_LIFECYCLE_ROLLUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
