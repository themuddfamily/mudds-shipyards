#!/usr/bin/env python3
"""Validate detached session-migration handoff evidence.

The handoff report covers epoch rotation, retained seat/ship/interest
attachments, current-epoch rebind, and packet sequence fencing from the
existing migration ledger. It is evidence structure only: no session or
transport is started.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_migration_handoff"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_session_migration_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _vector(value: Any) -> bool:
    return (
        isinstance(value, list)
        and len(value) == 3
        and all(isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(float(item)) for item in value)
    )


def _epoch(report: dict[str, Any], key: str, errors: list[str], label: str) -> dict[str, int] | None:
    value = report.get(key)
    if not isinstance(value, dict):
        errors.append(f"{label}.{key} must be an object")
        return None
    result: dict[str, int] = {}
    for field in ("package_generation", "session_generation", "migration_generation"):
        if not _positive_int(value.get(field)):
            errors.append(f"{label}.{key}.{field} must be positive")
        else:
            result[field] = value[field]
    return result


def validate_handoff(report: Any, label: str = "handoff") -> list[str]:
    """Return structural and migration-fence errors for one handoff."""

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
    if not _positive_int(report.get("peer_id")):
        errors.append(f"{label}.peer_id must be positive")

    initial = _epoch(report, "initial_epoch", errors, label)
    rotated = _epoch(report, "rotated_epoch", errors, label)
    if initial is not None and rotated is not None:
        for field in initial:
            if rotated[field] <= initial[field]:
                errors.append(f"{label}.rotated_epoch.{field} must advance beyond initial_epoch")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in (
            "server_owns_rotation",
            "server_owns_package_generation",
            "server_owns_session_generation",
            "server_owns_attachment_rebind",
            "stale_packets_rejected",
        ):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        if audit.get("client_can_mutate_attachment") is not False:
            errors.append(f"{label}.audit.client_can_mutate_attachment must be false")

    rotation = report.get("rotation")
    if not isinstance(rotation, dict):
        errors.append(f"{label}.rotation must be an object")
    else:
        if rotation.get("accepted") is not True or rotation.get("status") != "server_rotated":
            errors.append(f"{label}.rotation must be an accepted server_rotated receipt")
        if rotation.get("server_authority") is not True or rotation.get("rebind_required") is not True:
            errors.append(f"{label}.rotation must require server-owned rebind")
        if rotated is not None:
            for field in rotated:
                if rotation.get(field) != rotated[field]:
                    errors.append(f"{label}.rotation.{field} must match rotated_epoch")

    attachment = report.get("attachment")
    if not isinstance(attachment, dict):
        errors.append(f"{label}.attachment must be an object")
    else:
        seat = attachment.get("seat")
        ship = attachment.get("ship")
        interest = attachment.get("interest")
        if not isinstance(seat, dict) or not isinstance(seat.get("seat_id"), str) or not seat.get("seat_id").strip() or not _positive_int(seat.get("seat_generation")):
            errors.append(f"{label}.attachment.seat must contain an ID and positive generation")
        if not isinstance(ship, dict) or not isinstance(ship.get("ship_id"), str) or not ship.get("ship_id").strip() or not _positive_int(ship.get("ship_generation")):
            errors.append(f"{label}.attachment.ship must contain an ID and positive generation")
        if not isinstance(interest, dict) or not _vector(interest.get("center")):
            errors.append(f"{label}.attachment.interest.center must be a finite vector")
        elif not isinstance(interest.get("radius"), (int, float)) or isinstance(interest.get("radius"), bool) or not math.isfinite(float(interest["radius"])) or interest["radius"] <= 0:
            errors.append(f"{label}.attachment.interest.radius must be positive and finite")
        if not isinstance(interest, dict) or not _positive_int(interest.get("max_entities")) or interest["max_entities"] > 512:
            errors.append(f"{label}.attachment.interest.max_entities must be in 1..512")

    rebind = report.get("rebind")
    if not isinstance(rebind, dict):
        errors.append(f"{label}.rebind must be an object")
    else:
        if rebind.get("accepted") is not True or rebind.get("status") != "peer_rebound":
            errors.append(f"{label}.rebind must be an accepted peer_rebound receipt")
        if rebind.get("server_authority") is not True or rebind.get("attachments_restored") is not True:
            errors.append(f"{label}.rebind must restore attachments under server authority")
        if rebind.get("client_can_mutate_attachment") is not False:
            errors.append(f"{label}.rebind.client_can_mutate_attachment must be false")
        before = report.get("peer_generation_before")
        after = rebind.get("peer_generation")
        if not _positive_int(before) or not _positive_int(after) or after <= before:
            errors.append(f"{label}.rebind.peer_generation must advance beyond peer_generation_before")

    packet = report.get("accepted_packet")
    if not isinstance(packet, dict):
        errors.append(f"{label}.accepted_packet must be an object")
    else:
        if packet.get("accepted") is not True or packet.get("status") != "packet_accepted":
            errors.append(f"{label}.accepted_packet must be accepted")
        if not isinstance(packet.get("packet_sequence"), int) or packet["packet_sequence"] <= 0:
            errors.append(f"{label}.accepted_packet.packet_sequence must be positive")
        if packet.get("server_authority") is not True:
            errors.append(f"{label}.accepted_packet.server_authority must be true")

    required_rejections = {"stale_package_generation", "stale_session_generation", "stale_migration_generation", "spoofed_peer", "stale_packet_sequence"}
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
                errors.append(f"{prefix}.status is not a required migration rejection")
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
        for status in sorted(required_rejections - seen):
            errors.append(f"{label}.rejections must include {status}")
    return errors


def validate_handoff_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_handoff(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path)
    args = parser.parse_args()
    errors = validate_handoff_file(args.handoff)
    if errors:
        print("NETWORK_MIGRATION_HANDOFF_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_MIGRATION_HANDOFF_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
