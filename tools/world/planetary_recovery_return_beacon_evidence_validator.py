#!/usr/bin/env python3
"""Validate detached planetary recovery return-beacon evidence.

The evidence records authored failure routes from Ember activities to named
surface/orbit recovery beacons and then back to Mudds Shipyards.  It does not
accept recovery requests, move a player, mutate objective state, or run a
native scene.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_recovery_return_beacon"
EVIDENCE_MODE = "detached_beacon_evidence"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_RETURN_TARGET = "mudds_shipyards"
REQUIRED_RETURN_ROUTE_ID = "return_to_mudds"
REQUIRED_ACTIVITY_IDS = (
    "ember_beacon_survey",
    "ember_caldera_patrol",
    "ember_kit_cargo_run",
    "ember_checkpoint_race",
    "ember_convoy_escort",
)
RECOVERY_BEACONS = {
    "ember_landed_ship_beacon": ("return_to_landed_ship", "landed_ship"),
    "ember_orbit_return_beacon": ("abort_to_orbit_return", "orbit_return"),
    "ember_start_beacon": ("reset_at_start_beacon", "start_beacon"),
    "ember_convoy_return_beacon": ("recover_convoy_at_return_beacon", "convoy_return_beacon"),
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_evidence(value: Any, label: str = "evidence") -> list[str]:
    """Return blocking errors for one detached recovery beacon record."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("runtime_authority", "recovery_runtime", "movement_runtime", "save_runtime", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("return_target_id") != REQUIRED_RETURN_TARGET:
        errors.append(f"{label}.return_target_id must be {REQUIRED_RETURN_TARGET}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    beacons = value.get("beacons")
    if not isinstance(beacons, list) or len(beacons) != len(RECOVERY_BEACONS):
        errors.append(f"{label}.beacons must contain exactly four authored recovery beacons")
        beacons = []
    beacon_ids: list[Any] = []
    beacon_routes: dict[str, str] = {}
    for index, beacon in enumerate(beacons):
        prefix = f"{label}.beacons[{index}]"
        if not isinstance(beacon, dict):
            errors.append(f"{prefix} must be an object")
            continue
        beacon_id = beacon.get("id")
        beacon_ids.append(beacon_id)
        if beacon_id not in RECOVERY_BEACONS:
            errors.append(f"{prefix}.id must be an existing authored recovery beacon")
            expected_recovery = expected_target = None
        else:
            expected_recovery, expected_target = RECOVERY_BEACONS[beacon_id]
            beacon_routes[beacon_id] = beacon.get("recovery_route_id")
        if not _stable(beacon_id):
            errors.append(f"{prefix}.id must be stable lowercase text")
        if beacon.get("recovery_id") != expected_recovery:
            errors.append(f"{prefix}.recovery_id must match its authored beacon")
        if beacon.get("recovery_target") != expected_target:
            errors.append(f"{prefix}.recovery_target must match its authored beacon")
        if not _stable(beacon.get("recovery_route_id")):
            errors.append(f"{prefix}.recovery_route_id must be stable lowercase text")
        if beacon.get("route_destination") != beacon_id:
            errors.append(f"{prefix}.route_destination must terminate at the beacon")
        if beacon.get("return_route_id") != REQUIRED_RETURN_ROUTE_ID:
            errors.append(f"{prefix}.return_route_id must be {REQUIRED_RETURN_ROUTE_ID}")
        if beacon.get("authored_once") is not True:
            errors.append(f"{prefix}.authored_once must be true")
    _unique(beacon_ids, f"{label}.beacon_ids", errors)
    if tuple(beacon_ids) != tuple(RECOVERY_BEACONS):
        errors.append(f"{label}.beacons must retain authored recovery-beacon order")

    return_route = value.get("return_route")
    if not isinstance(return_route, dict):
        errors.append(f"{label}.return_route must be an object")
    else:
        if return_route.get("id") != REQUIRED_RETURN_ROUTE_ID:
            errors.append(f"{label}.return_route.id must be {REQUIRED_RETURN_ROUTE_ID}")
        if return_route.get("destination") != REQUIRED_RETURN_TARGET:
            errors.append(f"{label}.return_route.destination must be {REQUIRED_RETURN_TARGET}")
        if return_route.get("arrival_once") is not True:
            errors.append(f"{label}.return_route.arrival_once must be true")
        if return_route.get("loading_dead_end") is not False:
            errors.append(f"{label}.return_route.loading_dead_end must be false")

    activities = value.get("activities")
    if not isinstance(activities, list) or len(activities) != len(REQUIRED_ACTIVITY_IDS):
        errors.append(f"{label}.activities must contain exactly five authored activities")
        activities = []
    activity_ids: list[Any] = []
    objective_ids: list[Any] = []
    recovery_event_ids: list[Any] = []
    referenced_beacons: list[Any] = []
    for index, activity in enumerate(activities):
        prefix = f"{label}.activities[{index}]"
        if not isinstance(activity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = activity.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITY_IDS[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITY_IDS[index]}")
        objective_id = activity.get("objective_id")
        objective_ids.append(objective_id)
        if not _stable(objective_id):
            errors.append(f"{prefix}.objective_id must be stable lowercase text")
        beacon_id = activity.get("recovery_beacon_id")
        referenced_beacons.append(beacon_id)
        if beacon_id not in RECOVERY_BEACONS:
            errors.append(f"{prefix}.recovery_beacon_id must reference an authored beacon")
        else:
            expected_recovery, expected_target = RECOVERY_BEACONS[beacon_id]
            if activity.get("recovery_id") != expected_recovery:
                errors.append(f"{prefix}.recovery_id must match the recovery beacon")
            if activity.get("recovery_target") != expected_target:
                errors.append(f"{prefix}.recovery_target must match the recovery beacon")
            if activity.get("recovery_route_id") != beacon_routes.get(beacon_id):
                errors.append(f"{prefix}.recovery_route_id must terminate at its recovery beacon")
        if activity.get("return_route_id") != REQUIRED_RETURN_ROUTE_ID:
            errors.append(f"{prefix}.return_route_id must be {REQUIRED_RETURN_ROUTE_ID}")
        recovery_event_id = activity.get("recovery_event_id")
        recovery_event_ids.append(recovery_event_id)
        if not _stable(recovery_event_id):
            errors.append(f"{prefix}.recovery_event_id must be stable lowercase text")
        if activity.get("attempt_generation") != 1 or activity.get("retry_generation") != 2:
            errors.append(f"{prefix} must record one attempt followed by retry generation two")
        for key in ("recovery_requested_once", "recovery_accepted_once", "beacon_arrival_once", "stale_recovery_rejected", "retry_allowed", "return_presented_once", "returned_once"):
            if activity.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")
    if tuple(activity_ids) != REQUIRED_ACTIVITY_IDS:
        errors.append(f"{label}.activities must retain authored activity order")
    _unique(objective_ids, f"{label}.objective_ids", errors)
    _unique(recovery_event_ids, f"{label}.recovery_event_ids", errors)
    if set(referenced_beacons) != set(RECOVERY_BEACONS):
        errors.append(f"{label}.activities must cover every authored recovery beacon")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("activity", "objective", "recovery", "movement", "landing", "save", "network", "gameplay"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.evidence.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_RECOVERY_BEACON_INVALID: {exc}")
        return 1
    errors = validate_evidence(report)
    if errors:
        print("PLANETARY_RECOVERY_BEACON_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_RECOVERY_BEACON_VALID: detached return-beacon evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
