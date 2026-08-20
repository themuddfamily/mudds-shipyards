#!/usr/bin/env python3
"""Validate detached snapshot-digest stale replay evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_snapshot_digest_stale_replay"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
REQUIRED = {"stale_snapshot_digest", "stale_server_tick", "stale_snapshot_sequence", "stale_peer_generation"}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_replays(report: Any, label: str = "replay") -> list[str]:
    """Return stale replay and current-snapshot preservation errors."""

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
    if not _positive_int(current.get("peer_id")) or not _positive_int(current.get("peer_generation")):
        errors.append(f"{label}.current peer identity must be positive")
    for key in ("server_tick", "snapshot_sequence"):
        if not _positive_int(current.get(key)):
            errors.append(f"{label}.current.{key} must be positive")
    if not isinstance(current.get("partition_digest"), str) or not SHA256.fullmatch(current["partition_digest"]):
        errors.append(f"{label}.current.partition_digest must be lowercase SHA-256")

    accepted = report.get("accepted_current")
    if not isinstance(accepted, dict):
        errors.append(f"{label}.accepted_current must be an object")
    else:
        if accepted.get("accepted") is not True or accepted.get("status") != "snapshot_accepted":
            errors.append(f"{label}.accepted_current must be snapshot_accepted")
        for key in ("peer_id", "peer_generation", "server_tick", "snapshot_sequence", "partition_digest"):
            if accepted.get(key) != current.get(key):
                errors.append(f"{label}.accepted_current.{key} must match current snapshot")
        if accepted.get("server_committed") is not True or accepted.get("snapshot_detached") is not True:
            errors.append(f"{label}.accepted_current must be server-committed and detached")

    replays = report.get("replays")
    seen: set[str] = set()
    if not isinstance(replays, list):
        errors.append(f"{label}.replays must be an array")
        replays = []
    for index, replay in enumerate(replays):
        prefix = f"{label}.replays[{index}]"
        if not isinstance(replay, dict):
            errors.append(f"{prefix} must be an object")
            continue
        status = replay.get("status")
        if status not in REQUIRED:
            errors.append(f"{prefix}.status is not a required stale replay")
        else:
            seen.add(status)
        if replay.get("accepted") is not False or replay.get("server_rejected") is not True:
            errors.append(f"{prefix} must be server-rejected")
        if replay.get("state_changed") is not False:
            errors.append(f"{prefix}.state_changed must be false")
        if replay.get("current_peer_id") != current.get("peer_id") or replay.get("current_peer_generation") != current.get("peer_generation"):
            errors.append(f"{prefix} must retain current peer identity")
        if replay.get("current_server_tick") != current.get("server_tick") or replay.get("current_snapshot_sequence") != current.get("snapshot_sequence") or replay.get("current_partition_digest") != current.get("partition_digest"):
            errors.append(f"{prefix} must retain current snapshot state")
        if status == "stale_server_tick" and replay.get("attempted_server_tick", current["server_tick"]) >= current["server_tick"]:
            errors.append(f"{prefix}.attempted_server_tick must be older")
        if status == "stale_snapshot_sequence" and replay.get("attempted_snapshot_sequence", current["snapshot_sequence"]) >= current["snapshot_sequence"]:
            errors.append(f"{prefix}.attempted_snapshot_sequence must be older")
        if status == "stale_peer_generation" and replay.get("attempted_peer_generation", current["peer_generation"]) >= current["peer_generation"]:
            errors.append(f"{prefix}.attempted_peer_generation must be older")
        if status == "stale_snapshot_digest" and replay.get("attempted_partition_digest") == current.get("partition_digest"):
            errors.append(f"{prefix}.attempted_partition_digest must be stale")
    for status in sorted(REQUIRED - seen):
        errors.append(f"{label}.replays must include {status}")
    return errors


def validate_replays_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_replays(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("replay", type=Path)
    args = parser.parse_args()
    errors = validate_replays_file(args.replay)
    if errors:
        print("NETWORK_SNAPSHOT_DIGEST_STALE_REPLAY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_STALE_REPLAY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
