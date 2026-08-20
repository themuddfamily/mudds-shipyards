#!/usr/bin/env python3
"""Validate an authored planetary route/hazard/recovery evidence index."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_route_hazard_recovery_index_v1"
OPEN = {"pending", "not_performed", "unknown"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_index(value: Any, label: str = "index") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    routes = value.get("routes")
    if not isinstance(routes, list) or not routes:
        errors.append(f"{label}.routes must contain authored routes")
        routes = []
    route_ids: set[str] = set()
    for index, route in enumerate(routes):
        prefix = f"{label}.routes[{index}]"
        if not isinstance(route, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = route.get("id")
        if not _text(ident) or ident in route_ids:
            errors.append(f"{prefix}.id must be unique")
        route_ids.add(ident)
        if not _text(route.get("from_node")) or not _text(route.get("to_node")):
            errors.append(f"{prefix} requires from_node and to_node")
        if route.get("evidence_status") not in OPEN:
            errors.append(f"{prefix}.evidence_status must remain open")
    hazards = value.get("hazards")
    if not isinstance(hazards, list) or not hazards:
        errors.append(f"{label}.hazards must contain authored hazards")
        hazards = []
    hazard_ids: set[str] = set()
    for index, hazard in enumerate(hazards):
        prefix = f"{label}.hazards[{index}]"
        if not isinstance(hazard, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = hazard.get("id")
        if not _text(ident) or ident in hazard_ids:
            errors.append(f"{prefix}.id must be unique")
        hazard_ids.add(ident)
        if hazard.get("route_id") not in route_ids:
            errors.append(f"{prefix}.route_id must reference an authored route")
        if not _text(hazard.get("kind")) or not _text(hazard.get("recovery_id")):
            errors.append(f"{prefix} requires kind and recovery_id")
        if hazard.get("resolution") != "external_authority":
            errors.append(f"{prefix}.resolution must remain external_authority")
        evidence = hazard.get("evidence")
        if not isinstance(evidence, dict) or evidence.get("status") not in OPEN:
            errors.append(f"{prefix}.evidence.status must remain open")
        elif evidence.get("status") == "not_performed" and evidence.get("record") is not None:
            errors.append(f"{prefix}.evidence.record must be null when not_performed")
    recovery = value.get("recovery_handoffs")
    if not isinstance(recovery, list) or not recovery:
        errors.append(f"{label}.recovery_handoffs must contain authored handoffs")
        recovery = []
    recovery_ids: set[str] = set()
    for index, item in enumerate(recovery):
        prefix = f"{label}.recovery_handoffs[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = item.get("id")
        if not _text(ident) or ident in recovery_ids:
            errors.append(f"{prefix}.id must be unique")
        recovery_ids.add(ident)
        if item.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
        if item.get("status") == "not_performed" and item.get("evidence") is not None:
            errors.append(f"{prefix}.evidence must be null when not_performed")
    for hazard in hazards:
        if isinstance(hazard, dict) and _text(hazard.get("recovery_id")) and hazard["recovery_id"] not in recovery_ids:
            errors.append(f"hazard recovery_id must reference a recovery handoff: {hazard['recovery_id']}")
    gates = value.get("gates")
    if not isinstance(gates, dict):
        errors.append(f"{label}.gates must be an object")
    else:
        for key in ("native_run", "human_route_review"):
            if not isinstance(gates.get(key), dict) or gates[key].get("status") not in OPEN:
                errors.append(f"{label}.gates.{key}.status must remain open")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_ROUTE_HAZARD_RECOVERY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_ROUTE_HAZARD_RECOVERY_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
