#!/usr/bin/env python3
"""Validate detached multiplayer seat and ship ownership evidence.

The rollup composes the existing seat-role and ship-ownership ledgers. It
checks that accepted assignments match registered generations and roles, that
transfers retain a server-only source, and that stale/unauthorized attempts
are rejected. It does not mutate runtime authority or claim live-network
coverage.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_ownership_seat_authority"
EVIDENCE_MODE = "detached_contract_fixture"
SEAT_POLICY = "network_seat_role_authority_v1"
SHIP_POLICY = "network_ship_ownership_authority_v1"
ROLES = {"pilot", "gunner", "passenger", "engineer"}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_rollup(report: Any, label: str = "rollup") -> list[str]:
    """Return structural and ownership-boundary errors for one rollup."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("seat_policy", SEAT_POLICY),
        ("ship_policy", SHIP_POLICY),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in (
            "server_owns_seat_reservation",
            "server_owns_role_assignment",
            "server_owns_ship_claims",
            "server_owns_ship_transfers",
            "server_owns_ship_generations",
            "server_owns_disconnect_cleanup",
        ):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        for key in ("client_can_mutate_ledger", "client_can_mutate_ownership"):
            if audit.get(key) is not False:
                errors.append(f"{label}.audit.{key} must be false")

    seats = report.get("seats")
    seats_by_id: dict[str, dict[str, Any]] = {}
    if not isinstance(seats, list) or not seats:
        errors.append(f"{label}.seats must be a non-empty array")
        seats = []
    for index, seat in enumerate(seats):
        prefix = f"{label}.seats[{index}]"
        if not isinstance(seat, dict):
            errors.append(f"{prefix} must be an object")
            continue
        seat_id = seat.get("seat_id")
        if not isinstance(seat_id, str) or not seat_id.strip() or seat_id in seats_by_id:
            errors.append(f"{prefix}.seat_id must be unique and non-empty")
            continue
        seats_by_id[seat_id] = seat
        if not isinstance(seat.get("vessel_id"), str) or not seat["vessel_id"].strip():
            errors.append(f"{prefix}.vessel_id must be non-empty")
        if seat.get("role") not in ROLES:
            errors.append(f"{prefix}.role must be a supported crew role")
        if not _positive_int(seat.get("seat_generation")):
            errors.append(f"{prefix}.seat_generation must be positive")

    assignments = report.get("assignments")
    assigned_seats: set[str] = set()
    assigned_avatars: set[tuple[int, str]] = set()
    if not isinstance(assignments, list):
        errors.append(f"{label}.assignments must be an array")
        assignments = []
    for index, assignment in enumerate(assignments):
        prefix = f"{label}.assignments[{index}]"
        if not isinstance(assignment, dict):
            errors.append(f"{prefix} must be an object")
            continue
        seat_id = assignment.get("seat_id")
        occupant = assignment.get("occupant_peer_id")
        avatar = assignment.get("avatar_id")
        if seat_id not in seats_by_id:
            errors.append(f"{prefix}.seat_id must reference a registered seat")
        elif seat_id in assigned_seats:
            errors.append(f"{prefix}.seat_id must not be assigned twice")
        else:
            assigned_seats.add(seat_id)
            seat = seats_by_id[seat_id]
            if assignment.get("role") != seat.get("role"):
                errors.append(f"{prefix}.role must match the registered seat")
            if assignment.get("seat_generation") != seat.get("seat_generation"):
                errors.append(f"{prefix}.seat_generation must match the registered seat")
        if not _positive_int(occupant) or not isinstance(avatar, str) or not avatar.strip():
            errors.append(f"{prefix} occupant identity must be valid")
        else:
            key = (occupant, avatar)
            if key in assigned_avatars:
                errors.append(f"{prefix} avatar may not occupy two assignments")
            assigned_avatars.add(key)
        if assignment.get("server_committed") is not True:
            errors.append(f"{prefix}.server_committed must be true")

    ships = report.get("ships")
    ships_by_id: dict[str, dict[str, Any]] = {}
    if not isinstance(ships, list) or not ships:
        errors.append(f"{label}.ships must be a non-empty array")
        ships = []
    for index, ship in enumerate(ships):
        prefix = f"{label}.ships[{index}]"
        if not isinstance(ship, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ship_id = ship.get("ship_id")
        if not isinstance(ship_id, str) or not ship_id.strip() or ship_id in ships_by_id:
            errors.append(f"{prefix}.ship_id must be unique and non-empty")
            continue
        ships_by_id[ship_id] = ship
        if not _positive_int(ship.get("ship_generation")):
            errors.append(f"{prefix}.ship_generation must be positive")
        if not _non_negative_int(ship.get("owner_peer_id")):
            errors.append(f"{prefix}.owner_peer_id must be non-negative")
        if not _non_negative_int(ship.get("ownership_generation")):
            errors.append(f"{prefix}.ownership_generation must be non-negative")

    claim = report.get("claim")
    if not isinstance(claim, dict):
        errors.append(f"{label}.claim must be an object")
    else:
        if claim.get("accepted") is not True or claim.get("status") != "claimed":
            errors.append(f"{label}.claim must be an accepted claim receipt")
        if claim.get("server_committed") is not True:
            errors.append(f"{label}.claim.server_committed must be true")
        if claim.get("ship_id") not in ships_by_id:
            errors.append(f"{label}.claim.ship_id must reference a registered ship")
        if not _positive_int(claim.get("claimant_peer_id")):
            errors.append(f"{label}.claim.claimant_peer_id must be positive")

    transfer = report.get("transfer")
    if not isinstance(transfer, dict):
        errors.append(f"{label}.transfer must be an object")
    else:
        if transfer.get("accepted") is not True or transfer.get("status") != "transferred":
            errors.append(f"{label}.transfer must be an accepted transfer receipt")
        if transfer.get("server_committed") is not True:
            errors.append(f"{label}.transfer.server_committed must be true")
        if transfer.get("ship_id") != (claim or {}).get("ship_id"):
            errors.append(f"{label}.transfer.ship_id must match claim.ship_id")
        if transfer.get("from_peer_id") != (claim or {}).get("claimant_peer_id"):
            errors.append(f"{label}.transfer.from_peer_id must match the claimed owner")
        if not _positive_int(transfer.get("to_peer_id")):
            errors.append(f"{label}.transfer.to_peer_id must be positive")
        ship = ships_by_id.get(transfer.get("ship_id"))
        if ship is not None and transfer.get("ship_generation") != ship.get("ship_generation"):
            errors.append(f"{label}.transfer.ship_generation must match the ship")

    rejections = report.get("rejections")
    required_rejections = {"unauthorized_source", "role_mismatch", "stale_ship_generation", "owner_mismatch", "stale_request_sequence"}
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
    else:
        for index, rejection in enumerate(rejections):
            prefix = f"{label}.rejections[{index}]"
            status = rejection.get("status") if isinstance(rejection, dict) else None
            if status not in required_rejections:
                errors.append(f"{prefix}.status is not a required ownership rejection")
            else:
                seen.add(status)
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
        for status in sorted(required_rejections - seen):
            errors.append(f"{label}.rejections must include {status}")

    cleanup = report.get("cleanup")
    if not isinstance(cleanup, dict):
        errors.append(f"{label}.cleanup must be an object")
    else:
        if cleanup.get("accepted") is not True or cleanup.get("status") != "peer_released":
            errors.append(f"{label}.cleanup must be an accepted peer release")
        for key in ("seat_assignments_released", "ship_ownership_released", "server_committed"):
            if cleanup.get(key) is not True:
                errors.append(f"{label}.cleanup.{key} must be true")
        if cleanup.get("client_invoked") is not False:
            errors.append(f"{label}.cleanup.client_invoked must be false")
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
        print("NETWORK_OWNERSHIP_SEAT_AUTHORITY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_OWNERSHIP_SEAT_AUTHORITY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
