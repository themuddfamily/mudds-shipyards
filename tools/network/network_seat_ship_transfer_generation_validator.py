#!/usr/bin/env python3
"""Validate detached seat and ship transfer-generation evidence.

Transfers retain the registered seat/ship lifecycle generation while advancing
occupancy or ownership generations and request sequences. This fixture gate
checks those invariants and fail-closed stale-owner receipts without running a
ship or network session.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_seat_ship_transfer_generation"
EVIDENCE_MODE = "detached_contract_fixture"
SEAT_POLICY = "network_seat_role_authority_v1"
SHIP_POLICY = "network_ship_ownership_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_transfer(report: Any, label: str = "transfer") -> list[str]:
    """Return seat/ship transfer and generation-fence errors."""

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
        for key in ("server_owns_seat_reservation", "server_owns_role_assignment", "server_owns_ship_transfers", "server_owns_ship_generations"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        for key in ("client_can_mutate_ledger", "client_can_mutate_ownership"):
            if audit.get(key) is not False:
                errors.append(f"{label}.audit.{key} must be false")

    seat = report.get("seat")
    if not isinstance(seat, dict):
        errors.append(f"{label}.seat must be an object")
        seat = {}
    for key in ("seat_id", "role", "old_avatar_id", "new_avatar_id"):
        if not isinstance(seat.get(key), str) or not seat[key].strip():
            errors.append(f"{label}.seat.{key} must be non-empty")
    if seat.get("old_avatar_id") == seat.get("new_avatar_id"):
        errors.append(f"{label}.seat old and new avatars must differ")
    if not _positive_int(seat.get("seat_generation")):
        errors.append(f"{label}.seat.seat_generation must be positive")
    for key in ("release_sequence", "claim_sequence"):
        if not _non_negative_int(seat.get(key)):
            errors.append(f"{label}.seat.{key} must be non-negative")
    if _non_negative_int(seat.get("release_sequence")) and _non_negative_int(seat.get("claim_sequence")) and seat["claim_sequence"] <= seat["release_sequence"]:
        errors.append(f"{label}.seat.claim_sequence must advance beyond release_sequence")
    release = seat.get("release")
    if not isinstance(release, dict) or release.get("accepted") is not True or release.get("status") != "released" or release.get("server_committed") is not True:
        errors.append(f"{label}.seat.release must be server-committed released")
    elif release.get("seat_generation") != seat.get("seat_generation") or release.get("avatar_id") != seat.get("old_avatar_id"):
        errors.append(f"{label}.seat.release must match old avatar and generation")
    claim = seat.get("claim")
    if not isinstance(claim, dict) or claim.get("accepted") is not True or claim.get("status") != "claimed" or claim.get("server_committed") is not True:
        errors.append(f"{label}.seat.claim must be server-committed claimed")
    elif claim.get("seat_generation") != seat.get("seat_generation") or claim.get("avatar_id") != seat.get("new_avatar_id") or claim.get("role") != seat.get("role"):
        errors.append(f"{label}.seat.claim must preserve generation and role for new avatar")

    ship = report.get("ship")
    if not isinstance(ship, dict):
        errors.append(f"{label}.ship must be an object")
        ship = {}
    if not isinstance(ship.get("ship_id"), str) or not ship.get("ship_id").strip():
        errors.append(f"{label}.ship.ship_id must be non-empty")
    if not _positive_int(ship.get("ship_generation")):
        errors.append(f"{label}.ship.ship_generation must be positive")
    for key in ("from_peer_id", "to_peer_id"):
        if not _positive_int(ship.get(key)):
            errors.append(f"{label}.ship.{key} must be positive")
    if ship.get("from_peer_id") == ship.get("to_peer_id"):
        errors.append(f"{label}.ship from and to peers must differ")
    for key in ("ownership_generation_before", "ownership_generation_after"):
        if not _non_negative_int(ship.get(key)):
            errors.append(f"{label}.ship.{key} must be non-negative")
    if _non_negative_int(ship.get("ownership_generation_before")) and _non_negative_int(ship.get("ownership_generation_after")) and ship["ownership_generation_after"] != ship["ownership_generation_before"] + 1:
        errors.append(f"{label}.ship.ownership_generation_after must advance exactly once")
    for key in ("request_sequence_before", "request_sequence_after"):
        if not _non_negative_int(ship.get(key)):
            errors.append(f"{label}.ship.{key} must be non-negative")
    if _non_negative_int(ship.get("request_sequence_before")) and _non_negative_int(ship.get("request_sequence_after")) and ship["request_sequence_after"] <= ship["request_sequence_before"]:
        errors.append(f"{label}.ship.request_sequence_after must advance")
    transfer = ship.get("transfer")
    if not isinstance(transfer, dict) or transfer.get("accepted") is not True or transfer.get("status") != "transferred" or transfer.get("server_committed") is not True:
        errors.append(f"{label}.ship.transfer must be server-committed transferred")
    elif transfer.get("ship_generation") != ship.get("ship_generation") or transfer.get("from_peer_id") != ship.get("from_peer_id") or transfer.get("to_peer_id") != ship.get("to_peer_id"):
        errors.append(f"{label}.ship.transfer must preserve lifecycle generation and owner endpoints")

    required_rejections = {"stale_seat_generation", "stale_request_sequence", "owner_mismatch", "unauthorized_source"}
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
                errors.append(f"{prefix}.status is not a required transfer rejection")
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
        for status in sorted(required_rejections - seen):
            errors.append(f"{label}.rejections must include {status}")
    return errors


def validate_transfer_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_transfer(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("transfer", type=Path)
    args = parser.parse_args()
    errors = validate_transfer_file(args.transfer)
    if errors:
        print("NETWORK_SEAT_SHIP_TRANSFER_GENERATION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SEAT_SHIP_TRANSFER_GENERATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
