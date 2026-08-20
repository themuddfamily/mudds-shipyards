#!/usr/bin/env python3
"""Validate a detached planetary route/objective/reward return index.

The index is the evidence join between authored route IDs and the existing
activity, reward, return, and recovery authority keys.  It contains no route
graph runtime, objective state, inventory, or movement authority.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_route_objective_reward_return_index"
EVIDENCE_MODE = "detached_authored_index"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_RETURN_TARGET = "mudds_shipyards"
REQUIRED_REWARD_STORE = "game_flow_reward_store"
REQUIRED_REWARD_AUTHORITY = "game_flow_reward_authority"
REQUIRED_RETURN_AUTHORITY = "planetary_landing_return_contract"
REQUIRED_ACTIVITIES = (
    "ember_beacon_survey",
    "ember_caldera_patrol",
    "ember_kit_cargo_run",
    "ember_checkpoint_race",
    "ember_convoy_escort",
)
VALID_ACTIVITY_AUTHORITIES = {"activity_director", "cargo_delivery_activity", "timed_checkpoint_race", "convoy_escort_activity"}
VALID_RECOVERY_IDS = {"return_to_landed_ship", "abort_to_orbit_return", "reset_at_start_beacon", "recover_convoy_at_return_beacon"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _stable(value: Any) -> bool:
    return _text(value) and value == value.lower() and " " not in value and "__" not in value


def _unique(values: list[Any], label: str, errors: list[str]) -> None:
    if len(set(values)) != len(values):
        errors.append(f"{label} must not contain duplicates")


def validate_index(value: Any, label: str = "index") -> list[str]:
    """Return blocking errors for one detached route/objective index."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("route_runtime", "objective_runtime", "reward_inventory", "movement_authority", "native_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("return_target_id") != REQUIRED_RETURN_TARGET:
        errors.append(f"{label}.return_target_id must be {REQUIRED_RETURN_TARGET}")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")

    nodes = value.get("nodes")
    if not isinstance(nodes, list) or len(nodes) < 5:
        errors.append(f"{label}.nodes must contain at least five authored nodes")
        nodes = []
    node_ids: list[str] = []
    for index, node in enumerate(nodes):
        if not isinstance(node, dict) or not _stable(node.get("id")):
            errors.append(f"{label}.nodes[{index}].id must be stable lowercase text")
            continue
        node_ids.append(node["id"])
        if not _stable(node.get("role")):
            errors.append(f"{label}.nodes[{index}].role must be stable lowercase text")
    _unique(node_ids, f"{label}.nodes IDs", errors)
    node_set = set(node_ids)

    return_routes = value.get("return_routes")
    if not isinstance(return_routes, list) or not return_routes:
        errors.append(f"{label}.return_routes must contain an authored return route")
        return_routes = []
    return_route_ids: list[str] = []
    for index, route in enumerate(return_routes):
        prefix = f"{label}.return_routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        route_id = route.get("id")
        return_route_ids.append(route_id)
        if not _stable(route_id):
            errors.append(f"{prefix}.id must be stable lowercase text")
        route_nodes = route.get("nodes")
        if not isinstance(route_nodes, list) or len(route_nodes) < 2 or any(node not in node_set for node in route_nodes):
            errors.append(f"{prefix}.nodes must reference at least two authored nodes")
        if route.get("destination") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.destination must be {REQUIRED_RETURN_TARGET}")
        if route.get("return_complete") is not True:
            errors.append(f"{prefix}.return_complete must be true")
    _unique(return_route_ids, f"{label}.return_routes IDs", errors)

    records = value.get("records")
    if not isinstance(records, list) or len(records) != len(REQUIRED_ACTIVITIES):
        errors.append(f"{label}.records must contain exactly five authored activities")
        records = []
    activity_ids: list[str] = []
    objective_ids: list[str] = []
    reward_ids: list[str] = []
    route_ids: list[str] = []
    incentive_ids: list[str] = []
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        activity_id = record.get("activity_id")
        activity_ids.append(activity_id)
        if activity_id != REQUIRED_ACTIVITIES[index]:
            errors.append(f"{prefix}.activity_id must be {REQUIRED_ACTIVITIES[index]}")
        objective_ids.append(record.get("objective_id"))
        reward_ids.append(record.get("reward_id"))
        route_ids.append(record.get("route_id"))
        incentive_ids.append(record.get("return_incentive_id"))
        for key in ("activity_id", "objective_id", "reward_id", "route_id", "return_incentive_id", "return_route_id", "start_node_id", "finish_node_id"):
            if not _stable(record.get(key)):
                errors.append(f"{prefix}.{key} must be stable lowercase text")
        if record.get("start_node_id") not in node_set or record.get("finish_node_id") not in node_set:
            errors.append(f"{prefix} must reference authored start and finish nodes")
        if record.get("activity_authority_id") not in VALID_ACTIVITY_AUTHORITIES:
            errors.append(f"{prefix}.activity_authority_id must use an existing activity authority")
        if record.get("reward_authority_id") != REQUIRED_REWARD_AUTHORITY:
            errors.append(f"{prefix}.reward_authority_id must be {REQUIRED_REWARD_AUTHORITY}")
        if record.get("reward_store_id") != REQUIRED_REWARD_STORE:
            errors.append(f"{prefix}.reward_store_id must use the one canonical store")
        if record.get("return_route_id") not in return_route_ids:
            errors.append(f"{prefix}.return_route_id must reference an authored return route")
        if not record.get("return_incentive_id", "").startswith("return_"):
            errors.append(f"{prefix}.return_incentive_id must begin with return_")
        if record.get("return_target_id") != REQUIRED_RETURN_TARGET:
            errors.append(f"{prefix}.return_target_id must be {REQUIRED_RETURN_TARGET}")
        if record.get("recovery_id") not in VALID_RECOVERY_IDS:
            errors.append(f"{prefix}.recovery_id must use an existing recovery ID")
        if record.get("recovery_authority_id") != REQUIRED_RETURN_AUTHORITY:
            errors.append(f"{prefix}.recovery_authority_id must be {REQUIRED_RETURN_AUTHORITY}")
        if not _text(record.get("evidence_ref")) or not record["evidence_ref"].startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
    if tuple(activity_ids) != REQUIRED_ACTIVITIES:
        errors.append(f"{label}.records must retain authored activity order")
    _unique(objective_ids, f"{label}.objective_ids", errors)
    _unique(reward_ids, f"{label}.reward_ids", errors)
    _unique(route_ids, f"{label}.route_ids", errors)
    _unique(incentive_ids, f"{label}.return_incentive_ids", errors)

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("route", "objective", "activity", "reward", "reward_store", "recovery", "movement", "save", "network"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.index.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_ROUTE_INDEX_INVALID: {exc}")
        return 1
    errors = validate_index(report)
    if errors:
        print("PLANETARY_ROUTE_INDEX_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_ROUTE_INDEX_VALID: detached route/objective evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
