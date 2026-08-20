#!/usr/bin/env python3
"""Validate an authored planetary settlement and return-loop evidence record.

The record proves that a small surface route has an authored landing pad,
settlement, objective/hazard content, recovery edge, and explicit return to
Mudds Shipyards.  It does not generate terrain, fly a craft, stream a scene,
or turn a route sketch into a production playtest claim.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_settlement_return_loop"
EVIDENCE_MODE = "detached_authored_route_record"
MAX_NODES = 64
MAX_EDGES = 128
MAX_ROUTES = 16
MAX_ROUTE_NODES = 32
MIN_NODES = 5
STATUSES = {"PASS", "NOT_RUN", "UNKNOWN"}
REQUIRED_PHASE_PATH = (
    "orbit_approach",
    "descent",
    "surface_flight",
    "landed",
    "on_foot",
    "objective",
    "reboarded",
    "takeoff",
    "orbit_return",
)
REQUIRED_ROUTE_IDS = (
    "outbound_surface",
    "settlement_loop",
    "return_to_shipyard",
    "failure_recovery",
)
REQUIRED_NODE_ROLES = {
    "orbit_approach",
    "descent_gate",
    "landing_pad",
    "settlement",
    "return_beacon",
    "shipyard_return",
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _finite_vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(
        isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(item)
        for item in value
    )


def _status(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    status = value.get("status")
    if status not in STATUSES:
        errors.append(f"{label}.status is invalid")
    if status == "PASS" and not _text(value.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and value.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def _stable_ids(values: Any, label: str, errors: list[str]) -> set[str]:
    if not isinstance(values, list) or not values:
        errors.append(f"{label} must contain at least one ID")
        return set()
    seen: set[str] = set()
    for index, value in enumerate(values):
        if not _text(value) or value != value.lower() or " " in value:
            errors.append(f"{label}[{index}] must be lowercase stable text")
        elif value in seen:
            errors.append(f"{label} must not contain duplicate IDs")
        seen.add(value)
    return seen


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key, expected in (
        ("world_id", "ember_moon"),
        ("landing_region_id", "ember_caldera"),
        ("return_target_id", "mudds_shipyards"),
    ):
        if value.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    if not _text(value.get("unit_system")):
        errors.append(f"{label}.unit_system is required")
    if value.get("procedural_generation") is not False:
        errors.append(f"{label}.procedural_generation must be false")

    nodes = value.get("nodes")
    if not isinstance(nodes, list) or not MIN_NODES <= len(nodes) <= MAX_NODES:
        errors.append(f"{label}.nodes must contain {MIN_NODES}..{MAX_NODES} entries")
        nodes = []
    node_ids: set[str] = set()
    node_roles: set[str] = set()
    for index, node in enumerate(nodes):
        prefix = f"{label}.nodes[{index}]"
        if not isinstance(node, dict):
            errors.append(f"{prefix} must be an object")
            continue
        node_id = node.get("id")
        if not _text(node_id):
            errors.append(f"{prefix}.id is required")
        elif node_id in node_ids:
            errors.append(f"{label}.nodes IDs must be unique")
        else:
            node_ids.add(node_id)
        role = node.get("role")
        if not _text(role):
            errors.append(f"{prefix}.role is required")
        else:
            node_roles.add(role)
        if not _finite_vector(node.get("body_local_m")):
            errors.append(f"{prefix}.body_local_m must be three finite metres")
    if not REQUIRED_NODE_ROLES.issubset(node_roles):
        errors.append(f"{label}.nodes must include authored orbit, landing, settlement, return, and shipyard roles")

    edges = value.get("edges")
    if not isinstance(edges, list) or not edges:
        errors.append(f"{label}.edges must contain at least one edge")
        edges = []
    if len(edges) > MAX_EDGES:
        errors.append(f"{label}.edges must contain at most {MAX_EDGES} entries")
    edge_pairs: set[tuple[str, str]] = set()
    adjacency: dict[str, set[str]] = {node_id: set() for node_id in node_ids}
    for index, edge in enumerate(edges):
        prefix = f"{label}.edges[{index}]"
        if not isinstance(edge, dict) or not _text(edge.get("from")) or not _text(edge.get("to")):
            errors.append(f"{prefix} requires from and to")
            continue
        source, target = edge["from"], edge["to"]
        if source not in node_ids or target not in node_ids:
            errors.append(f"{prefix} references an unknown node")
        if source == target:
            errors.append(f"{prefix} must not self-loop")
        pair = (source, target)
        if pair in edge_pairs:
            errors.append(f"{label}.edges must not duplicate directed pairs")
        edge_pairs.add(pair)
        adjacency.setdefault(source, set()).add(target)
        length = edge.get("maximum_length_m")
        if not isinstance(length, (int, float)) or isinstance(length, bool) or not math.isfinite(length) or length <= 0:
            errors.append(f"{prefix}.maximum_length_m must be a positive finite number")

    routes = value.get("routes")
    if not isinstance(routes, list) or not 1 <= len(routes) <= MAX_ROUTES:
        errors.append(f"{label}.routes must contain 1..{MAX_ROUTES} entries")
        routes = []
    route_ids: set[str] = set()
    route_order: list[str] = []
    for index, route in enumerate(routes):
        prefix = f"{label}.routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        route_id = route.get("id")
        if not _text(route_id):
            errors.append(f"{prefix}.id is required")
            continue
        if route_id in route_ids:
            errors.append(f"{label}.routes IDs must be unique")
        route_ids.add(route_id)
        route_order.append(route_id)
        route_nodes = route.get("nodes")
        if not isinstance(route_nodes, list) or not 2 <= len(route_nodes) <= MAX_ROUTE_NODES:
            errors.append(f"{prefix}.nodes must contain 2..{MAX_ROUTE_NODES} node IDs")
            continue
        for node_id in route_nodes:
            if node_id not in node_ids:
                errors.append(f"{prefix}.nodes references an unknown node")
        for source, target in zip(route_nodes, route_nodes[1:]):
            if (source, target) not in edge_pairs:
                errors.append(f"{prefix} has a segment without an authored edge")
        if route_id == "return_to_shipyard":
            if route_nodes[-1] not in node_ids or route.get("destination") != "mudds_shipyards":
                errors.append(f"{prefix} must terminate at the Mudds Shipyards return node")
        _status(route.get("evidence"), f"{prefix}.evidence", errors)
    if tuple(route_order) != REQUIRED_ROUTE_IDS:
        errors.append(f"{label}.routes must contain the four authored outbound, settlement, return, and recovery routes")

    settlement = value.get("settlement")
    if not isinstance(settlement, dict):
        errors.append(f"{label}.settlement must be an object")
    else:
        for key in ("id", "landing_node_id", "return_beacon_node_id"):
            if not _text(settlement.get(key)):
                errors.append(f"{label}.settlement.{key} is required")
        for key in ("landing_node_id", "return_beacon_node_id"):
            if settlement.get(key) not in node_ids:
                errors.append(f"{label}.settlement.{key} references an unknown node")
        _stable_ids(settlement.get("objective_ids"), f"{label}.settlement.objective_ids", errors)
        _stable_ids(settlement.get("hazard_ids"), f"{label}.settlement.hazard_ids", errors)
        if settlement.get("recoverable_failure") is not True:
            errors.append(f"{label}.settlement.recoverable_failure must be true")

    loop = value.get("loop")
    if not isinstance(loop, dict):
        errors.append(f"{label}.loop must be an object")
    else:
        if tuple(loop.get("phase_path", [])) != REQUIRED_PHASE_PATH:
            errors.append(f"{label}.loop.phase_path must cover orbit, landing, on-foot, and return")
        for key in ("outbound_route_id", "settlement_route_id", "return_route_id", "recovery_route_id"):
            if loop.get(key) not in route_ids:
                errors.append(f"{label}.loop.{key} must reference an authored route")
        if loop.get("same_shipyard_identity") is not True:
            errors.append(f"{label}.loop.same_shipyard_identity must be true")
        if loop.get("loading_dead_end") is not False:
            errors.append(f"{label}.loop.loading_dead_end must be false")
        if loop.get("stranded_player") is not False:
            errors.append(f"{label}.loop.stranded_player must be false")

    _status(value.get("native_playtest"), f"{label}.native_playtest", errors)
    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("navigation_runtime", "settlement_runtime", "hazard_runtime", "landing_runtime", "movement", "reward"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_SETTLEMENT_RETURN_INVALID: {exc}")
        return 1
    errors = validate_manifest(value)
    if errors:
        print("PLANETARY_SETTLEMENT_RETURN_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SETTLEMENT_RETURN_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
