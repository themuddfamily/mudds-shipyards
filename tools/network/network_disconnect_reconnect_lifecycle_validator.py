#!/usr/bin/env python3
"""Validate detached disconnect/reconnect lifecycle evidence.

The rollup composes the existing disconnect lifecycle contract: server-owned
cleanup removes the old peer's seat, ship, and interest state; stale cleanup or
rejoin attempts fail closed; and a strictly newer peer generation can be
admitted with fresh attachments. No live session or transport is started.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_disconnect_reconnect_lifecycle"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_disconnect_lifecycle_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_lifecycle(report: Any, label: str = "lifecycle") -> list[str]:
    """Return cleanup, generation-fence, and reconnect errors for one report."""

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
    for key in ("native_claims", "uses_live_sessions"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in (
            "server_owns_disconnect_cleanup",
            "server_owns_session_rotation",
            "server_owns_interest_cleanup",
            "stale_rejoins_rejected",
        ):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        if audit.get("client_can_mutate_lifecycle") is not False:
            errors.append(f"{label}.audit.client_can_mutate_lifecycle must be false")

    peer = report.get("peer")
    if not isinstance(peer, dict):
        errors.append(f"{label}.peer must be an object")
        peer = {}
    if not _positive_int(peer.get("peer_id")):
        errors.append(f"{label}.peer.peer_id must be positive")
    for key in ("generation_before", "generation_after"):
        if not _positive_int(peer.get(key)):
            errors.append(f"{label}.peer.{key} must be positive")
    if _positive_int(peer.get("generation_before")) and _positive_int(peer.get("generation_after")) and peer["generation_after"] <= peer["generation_before"]:
        errors.append(f"{label}.peer.generation_after must advance beyond generation_before")

    initial = report.get("initial_state")
    if not isinstance(initial, dict):
        errors.append(f"{label}.initial_state must be an object")
    else:
        if initial.get("active") is not True:
            errors.append(f"{label}.initial_state.active must be true")
        for key in ("seat_attached", "ship_attached", "interest_attached"):
            if initial.get(key) is not True:
                errors.append(f"{label}.initial_state.{key} must be true")

    disconnect = report.get("disconnect")
    if not isinstance(disconnect, dict):
        errors.append(f"{label}.disconnect must be an object")
        disconnect = {}
    if disconnect.get("accepted") is not True or disconnect.get("status") != "disconnected":
        errors.append(f"{label}.disconnect must be an accepted disconnected receipt")
    if disconnect.get("source_peer_id") != disconnect.get("authority_peer_id"):
        errors.append(f"{label}.disconnect must be invoked by authority")
    if disconnect.get("peer_generation") != peer.get("generation_before"):
        errors.append(f"{label}.disconnect.peer_generation must match the active generation")
    for key in ("peer_removed", "seat_cleanup", "ship_cleanup", "interest_removed"):
        if disconnect.get(key) is not True:
            errors.append(f"{label}.disconnect.{key} must be true")
    if disconnect.get("active_after") is not False:
        errors.append(f"{label}.disconnect.active_after must be false")

    reconnect = report.get("reconnect")
    if not isinstance(reconnect, dict):
        errors.append(f"{label}.reconnect must be an object")
        reconnect = {}
    if reconnect.get("accepted") is not True or reconnect.get("status") != "admitted":
        errors.append(f"{label}.reconnect must be an admitted receipt")
    if reconnect.get("source_peer_id") != reconnect.get("peer_id") or reconnect.get("peer_id") != peer.get("peer_id"):
        errors.append(f"{label}.reconnect source and peer identity must match")
    if reconnect.get("peer_generation") != peer.get("generation_after"):
        errors.append(f"{label}.reconnect.peer_generation must match the newer generation")
    if reconnect.get("attachments_restored") is not True or reconnect.get("server_committed") is not True:
        errors.append(f"{label}.reconnect must restore attachments under server authority")
    if reconnect.get("client_can_mutate_lifecycle") is not False:
        errors.append(f"{label}.reconnect.client_can_mutate_lifecycle must be false")

    final = report.get("final_state")
    if not isinstance(final, dict):
        errors.append(f"{label}.final_state must be an object")
    else:
        if final.get("active") is not True:
            errors.append(f"{label}.final_state.active must be true")
        if final.get("peer_generation") != peer.get("generation_after"):
            errors.append(f"{label}.final_state.peer_generation must match reconnect")
        for key in ("seat_attached", "ship_attached", "interest_attached"):
            if final.get(key) is not True:
                errors.append(f"{label}.final_state.{key} must be true")

    required_rejections = {"unauthorized_source", "stale_peer_generation", "stale_session_generation"}
    rejections = report.get("rejections")
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
    else:
        for index, rejection in enumerate(rejections):
            prefix = f"{label}.rejections[{index}]"
            status = rejection.get("status") if isinstance(rejection, dict) else None
            if status in required_rejections:
                seen.add(status)
            else:
                errors.append(f"{prefix}.status is not a required lifecycle rejection")
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
        for status in sorted(required_rejections - seen):
            errors.append(f"{label}.rejections must include {status}")
    return errors


def validate_lifecycle_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_lifecycle(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lifecycle", type=Path)
    args = parser.parse_args()
    errors = validate_lifecycle_file(args.lifecycle)
    if errors:
        print("NETWORK_DISCONNECT_RECONNECT_LIFECYCLE_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_DISCONNECT_RECONNECT_LIFECYCLE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
