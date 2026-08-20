#!/usr/bin/env python3
"""Validate visible/deferred snapshot digest continuity evidence.

The guard checks an ordered detached snapshot sequence: unchanged partitions
retain their digest, changed partitions advance it, and stale digest replays
cannot change the current snapshot. No live network or transport is used.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_visible_deferred_snapshot_digest_guard"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def validate_guard(report: Any, label: str = "guard") -> list[str]:
    """Return digest continuity and stale replay errors."""

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
    if not isinstance(report.get("peer_id"), int) or isinstance(report.get("peer_id"), bool) or report["peer_id"] <= 0:
        errors.append(f"{label}.peer_id must be positive")

    snapshots = report.get("snapshots")
    if not isinstance(snapshots, list) or not snapshots:
        errors.append(f"{label}.snapshots must be a non-empty array")
        snapshots = []
    previous_tick = -1
    previous_digest: str | None = None
    for index, snapshot in enumerate(snapshots):
        prefix = f"{label}.snapshots[{index}]"
        if not isinstance(snapshot, dict):
            errors.append(f"{prefix} must be an object")
            continue
        tick = snapshot.get("server_tick")
        if not isinstance(tick, int) or isinstance(tick, bool) or tick <= previous_tick:
            errors.append(f"{prefix}.server_tick must be strictly increasing")
        else:
            previous_tick = tick
        digest = snapshot.get("partition_digest")
        if not isinstance(digest, str) or not SHA256.fullmatch(digest):
            errors.append(f"{prefix}.partition_digest must be lowercase SHA-256")
        changed = snapshot.get("partition_changed")
        if not isinstance(changed, bool):
            errors.append(f"{prefix}.partition_changed must be boolean")
        if index == 0:
            if snapshot.get("previous_digest") is not None:
                errors.append(f"{prefix}.previous_digest must be null for the first snapshot")
        else:
            if snapshot.get("previous_digest") != previous_digest:
                errors.append(f"{prefix}.previous_digest must match the prior digest")
            if isinstance(changed, bool) and isinstance(digest, str) and isinstance(previous_digest, str):
                if changed and digest == previous_digest:
                    errors.append(f"{prefix} changed partition must advance digest")
                if not changed and digest != previous_digest:
                    errors.append(f"{prefix} unchanged partition must retain digest")
        if snapshot.get("accepted") is not True or snapshot.get("server_committed") is not True:
            errors.append(f"{prefix} must be an accepted server-committed snapshot")
        if isinstance(digest, str):
            previous_digest = digest

    replays = report.get("stale_replays")
    if not isinstance(replays, list) or not replays:
        errors.append(f"{label}.stale_replays must be a non-empty array")
        replays = []
    for index, replay in enumerate(replays):
        prefix = f"{label}.stale_replays[{index}]"
        if not isinstance(replay, dict):
            errors.append(f"{prefix} must be an object")
            continue
        digest = replay.get("replayed_digest")
        if not isinstance(digest, str) or not SHA256.fullmatch(digest):
            errors.append(f"{prefix}.replayed_digest must be lowercase SHA-256")
        if replay.get("accepted") is not False or replay.get("status") != "stale_snapshot_digest":
            errors.append(f"{prefix} must be rejected stale_snapshot_digest")
        if replay.get("server_rejected") is not True or replay.get("state_changed") is not False:
            errors.append(f"{prefix} must be server-rejected without state change")
        if replay.get("current_digest") != previous_digest:
            errors.append(f"{prefix}.current_digest must match the final snapshot")
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    return errors


def validate_guard_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_guard(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("guard", type=Path)
    args = parser.parse_args()
    errors = validate_guard_file(args.guard)
    if errors:
        print("NETWORK_VISIBLE_DEFERRED_SNAPSHOT_DIGEST_GUARD_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_VISIBLE_DEFERRED_SNAPSHOT_DIGEST_GUARD_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
