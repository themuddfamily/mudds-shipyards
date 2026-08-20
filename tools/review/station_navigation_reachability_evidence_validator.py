#!/usr/bin/env python3
"""Validate detached station navigation/reachability evidence.

The ledger checks the declarative station route graph: seven authored module
slots pair with seven world-owned hub endpoints and no slot is dangling or
overclaimed. It deliberately does not claim that a player can physically walk
the route. Human map sweep, collision continuity, and visual wayfinding remain
open external gates.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "station_navigation_reachability_evidence_v1"
HUB_ID = "station-hub"
EXPECTED_MODULES = {
    "aft-junction-stack": "approach",
    "fabrication_annex": "annex_inbound",
    "fleet-dock-comb": "approach",
    "habitat-spine": "approach",
    "jovian-freight-berth": "approach",
    "observation-logistics-spur": "origin",
    "salvage-terrace": "connector",
}
EVIDENCE_KINDS = {"report", "log", "image", "video"}
OPEN_STATUSES = {"pending", "not_performed", "in_progress"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _reference(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object")
        return
    if not isinstance(value.get("kind"), str) or value.get("kind") not in EVIDENCE_KINDS:
        errors.append(f"{prefix}.kind must be report, log, image, or video")
    if not _text(value.get("path")):
        errors.append(f"{prefix}.path must be non-empty text")
    if not _sha(value.get("sha256")):
        errors.append(f"{prefix}.sha256 must be a lowercase digest")


def _validate_module(module: Any, index: int, evidence_seen: set[tuple[str, str]]) -> list[str]:
    prefix = f"modules[{index}]"
    if not isinstance(module, dict):
        return [f"{prefix} must be an object"]
    errors: list[str] = []
    module_id = module.get("module_id")
    if not isinstance(module_id, str) or module_id not in EXPECTED_MODULES:
        errors.append(f"{prefix}.module_id must be one of the seven production modules")
    route_id = module.get("route_id")
    if isinstance(module_id, str) and module_id in EXPECTED_MODULES and route_id != EXPECTED_MODULES[module_id]:
        errors.append(f"{prefix}.route_id does not match the module's declared connection route")
    for key in ("slot_id", "hub_endpoint_id", "module_endpoint_id", "node_id"):
        if not _text(module.get(key)):
            errors.append(f"{prefix}.{key} must be non-empty text")
    if module.get("evidence_status") != "modern_interpretation":
        errors.append(f"{prefix}.evidence_status must remain modern_interpretation")
    if module.get("historical_authentication") is not False:
        errors.append(f"{prefix}.historical_authentication must be false")
    if module.get("reachable_from_hub") is not True:
        errors.append(f"{prefix}.reachable_from_hub must be true in the declarative graph")
    if module.get("claim_count") != 2:
        errors.append(f"{prefix}.claim_count must be exactly two")
    if module.get("path_hops") != 1:
        errors.append(f"{prefix}.path_hops must be one hub edge")
    endpoints = module.get("edge_endpoints")
    if not isinstance(endpoints, list) or len(endpoints) != 2 or any(not _text(item) for item in endpoints):
        errors.append(f"{prefix}.edge_endpoints must contain two endpoint IDs")
    elif len(set(endpoints)) != 2:
        errors.append(f"{prefix}.edge_endpoints must contain distinct endpoints")
    elif module.get("hub_endpoint_id") not in endpoints or module.get("module_endpoint_id") not in endpoints:
        errors.append(f"{prefix}.edge_endpoints must include both declared endpoints")
    evidence = module.get("evidence")
    _reference(evidence, f"{prefix}.evidence", errors)
    if isinstance(evidence, dict) and _text(evidence.get("path")) and _sha(evidence.get("sha256")):
        identity = (evidence["path"], evidence["sha256"])
        if identity in evidence_seen:
            errors.append(f"{prefix}.evidence duplicates an earlier evidence reference")
        evidence_seen.add(identity)
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the graph evidence is coherent."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("source_revision", "graph_source", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    if not isinstance(value.get("human_map_sweep_status"), str) or value.get("human_map_sweep_status") not in OPEN_STATUSES:
        errors.append("human_map_sweep_status must remain pending, not_performed, or in_progress")
    if value.get("physical_traversability_proven") is not False:
        errors.append("physical_traversability_proven must remain false")
    if value.get("historical_authentication") is not False:
        errors.append("historical_authentication must remain false")
    summary = value.get("graph_summary")
    if not isinstance(summary, dict):
        errors.append("graph_summary must be an object")
    else:
        expected = {
            "hub_id": HUB_ID,
            "module_count": 7,
            "node_count": 8,
            "edge_count": 7,
            "component_count": 1,
            "dangling_slot_count": 0,
            "overclaimed_slot_count": 0,
        }
        for key, expected_value in expected.items():
            if summary.get(key) != expected_value:
                errors.append(f"graph_summary.{key} must be {expected_value!r}")
        for key in ("module_count", "node_count", "edge_count", "component_count", "dangling_slot_count", "overclaimed_slot_count"):
            if not _nonnegative_int(summary.get(key)):
                errors.append(f"graph_summary.{key} must be a non-negative integer")

    modules = value.get("modules")
    if not isinstance(modules, list) or len(modules) != len(EXPECTED_MODULES):
        errors.append("modules must contain exactly seven entries")
        modules = modules if isinstance(modules, list) else []
    ids: list[str] = []
    slots: list[str] = []
    evidence_seen: set[tuple[str, str]] = set()
    for index, module in enumerate(modules):
        if isinstance(module, dict):
            if _text(module.get("module_id")):
                ids.append(module["module_id"])
            if _text(module.get("slot_id")):
                slots.append(module["slot_id"])
        errors.extend(_validate_module(module, index, evidence_seen))
    if len(ids) != len(set(ids)):
        errors.append("modules.module_id values must be unique")
    if set(ids) != set(EXPECTED_MODULES):
        errors.append("modules must exactly cover the seven production module IDs")
    if len(slots) != len(set(slots)):
        errors.append("modules.slot_id values must be unique")

    adjacency = value.get("adjacency")
    if not isinstance(adjacency, dict):
        errors.append("adjacency must be an object")
    else:
        for key, expected_value in (("edge_count", 7), ("connected_slots", 7), ("total_slots", 7), ("dangling_slot_count", 0), ("overclaimed_slot_count", 0)):
            if adjacency.get(key) != expected_value:
                errors.append(f"adjacency.{key} must be {expected_value}")
        for key in ("edge_count", "connected_slots", "total_slots", "dangling_slot_count", "overclaimed_slot_count"):
            if not _nonnegative_int(adjacency.get(key)):
                errors.append(f"adjacency.{key} must be a non-negative integer")
        for key in ("dangling_slots", "overclaimed_slots"):
            if adjacency.get(key) != []:
                errors.append(f"adjacency.{key} must be an empty list")
        if adjacency.get("server_or_world_authority") is not True:
            errors.append("adjacency.server_or_world_authority must be true")
        if adjacency.get("client_can_mutate") is not False:
            errors.append("adjacency.client_can_mutate must be false")
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"ledger unreadable: {exc}"]
    return validate_ledger(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.ledger)
    if errors:
        print("STATION_NAVIGATION_REACHABILITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("STATION_NAVIGATION_REACHABILITY_READY: human map sweep remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
