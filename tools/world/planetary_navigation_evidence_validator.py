#!/usr/bin/env python3
"""Validate authored planetary route and landing evidence.

This validator checks a small, human-readable evidence record only.  It does
not generate navigation, raycast terrain, stream a planet, or move a craft.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
MAX_NODES = 128
MAX_EDGES = 256
MAX_LANDING_SITES = 16
STATUSES = {"PASS", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _status(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    if value.get("status") not in STATUSES:
        errors.append(f"{label}.status is invalid")
    if value.get("status") == "PASS" and not _text(value.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if value.get("status") in {"NOT_RUN", "UNKNOWN"} and value.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {value.get('status')}")


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("world_id", "region_id", "unit_system"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    nodes = value.get("nodes")
    if not isinstance(nodes, list) or not 1 <= len(nodes) <= MAX_NODES:
        errors.append(f"{label}.nodes must contain 1..{MAX_NODES} entries")
        nodes = []
    node_ids: set[str] = set()
    positions: dict[str, tuple[float, float, float]] = {}
    for index, node in enumerate(nodes):
        if not isinstance(node, dict) or not _text(node.get("id")):
            errors.append(f"{label}.nodes[{index}].id is required")
            continue
        node_id = node["id"]
        if node_id in node_ids:
            errors.append(f"{label}.nodes IDs must be unique")
        node_ids.add(node_id)
        position = node.get("body_local_m")
        if not isinstance(position, list) or len(position) != 3 or not all(isinstance(item, (int, float)) and math.isfinite(item) for item in position):
            errors.append(f"{label}.nodes[{index}].body_local_m must be three finite metres")
        else:
            positions[node_id] = tuple(float(item) for item in position)

    edges = value.get("edges")
    if not isinstance(edges, list) or len(edges) > MAX_EDGES:
        errors.append(f"{label}.edges must contain at most {MAX_EDGES} entries")
        edges = []
    seen_edges: set[tuple[str, str]] = set()
    adjacency: dict[str, set[str]] = {node_id: set() for node_id in node_ids}
    for index, edge in enumerate(edges):
        if not isinstance(edge, dict) or not _text(edge.get("from")) or not _text(edge.get("to")):
            errors.append(f"{label}.edges[{index}] requires from and to")
            continue
        source, target = edge["from"], edge["to"]
        if source not in node_ids or target not in node_ids:
            errors.append(f"{label}.edges[{index}] references an unknown node")
        if source == target:
            errors.append(f"{label}.edges[{index}] must not self-loop")
        if (source, target) in seen_edges:
            errors.append(f"{label}.edges must not duplicate directed edges")
        seen_edges.add((source, target))
        adjacency.setdefault(source, set()).add(target)
        if source in positions and target in positions and edge.get("maximum_length_m") is not None:
            limit = edge["maximum_length_m"]
            distance = math.dist(positions[source], positions[target])
            if not isinstance(limit, (int, float)) or not math.isfinite(limit) or limit <= 0 or distance > limit:
                errors.append(f"{label}.edges[{index}] exceeds its authored maximum length")

    if node_ids and edges:
        reachable = {next(iter(node_ids))}
        changed = True
        while changed:
            changed = False
            for source in tuple(reachable):
                before = len(reachable)
                reachable.update(adjacency.get(source, set()))
                changed |= len(reachable) != before
        if reachable != node_ids:
            errors.append(f"{label}.route graph must reach every authored node from its root")

    sites = value.get("landing_sites")
    if not isinstance(sites, list) or not 1 <= len(sites) <= MAX_LANDING_SITES:
        errors.append(f"{label}.landing_sites must contain 1..{MAX_LANDING_SITES} entries")
        sites = []
    site_ids: set[str] = set()
    for index, site in enumerate(sites):
        if not isinstance(site, dict) or not _text(site.get("id")):
            errors.append(f"{label}.landing_sites[{index}].id is required")
            continue
        if site["id"] in site_ids:
            errors.append(f"{label}.landing_sites IDs must be unique")
        site_ids.add(site["id"])
        if site.get("node_id") not in node_ids:
            errors.append(f"{label}.landing_sites[{index}] references an unknown node")
        if not _text(site.get("route_id")):
            errors.append(f"{label}.landing_sites[{index}].route_id is required")
        _status(site.get("evidence"), f"{label}.landing_sites[{index}].evidence", errors)

    _status(value.get("native_playtest"), f"{label}.native_playtest", errors)
    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("navigation_runtime", "landing_runtime", "terrain_generation", "movement"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_NAVIGATION_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_NAVIGATION_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
