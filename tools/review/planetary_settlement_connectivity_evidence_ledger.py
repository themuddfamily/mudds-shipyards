#!/usr/bin/env python3
"""Validate authored settlement landmark route connectivity evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_settlement_connectivity_evidence_v1"
OPEN = {"pending", "not_performed"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "settlement_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    nodes = value.get("nodes")
    if not isinstance(nodes, list) or not nodes:
        errors.append(f"{label}.nodes must contain authored nodes")
        nodes = []
    node_ids: set[str] = set()
    for index, node in enumerate(nodes):
        prefix = f"{label}.nodes[{index}]"
        if not isinstance(node, dict) or not _text(node.get("id")):
            errors.append(f"{prefix}.id is required")
            continue
        ident = node["id"]
        if ident in node_ids:
            errors.append(f"{prefix}.id must be unique")
        node_ids.add(ident)
        if node.get("role") not in {"landing_pad", "relay", "landmark", "exit"}:
            errors.append(f"{prefix}.role is invalid")
    edges = value.get("edges")
    if not isinstance(edges, list) or not edges:
        errors.append(f"{label}.edges must contain authored connections")
        edges = []
    adjacency: dict[str, set[str]] = {ident: set() for ident in node_ids}
    edge_ids: set[str] = set()
    for index, edge in enumerate(edges):
        prefix = f"{label}.edges[{index}]"
        if not isinstance(edge, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = edge.get("id")
        if not _text(ident) or ident in edge_ids:
            errors.append(f"{prefix}.id must be unique")
        edge_ids.add(ident)
        source, target = edge.get("from"), edge.get("to")
        if source not in node_ids or target not in node_ids:
            errors.append(f"{prefix} must reference known nodes")
        else:
            adjacency[source].add(target)
        if edge.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if not _text(edge.get("route_id")):
            errors.append(f"{prefix}.route_id is required")
    if node_ids and edges:
        roots = [node.get("id") for node in nodes if isinstance(node, dict) and node.get("role") == "landing_pad"]
        reachable = set(roots[:1])
        changed = True
        while changed:
            changed = False
            for source in tuple(reachable):
                before = len(reachable)
                reachable.update(adjacency.get(source, set()))
                changed |= len(reachable) != before
        if not roots or reachable != node_ids:
            errors.append(f"{label}.connectivity must reach every node from the landing pad")
    evidence = value.get("connectivity_evidence")
    if not isinstance(evidence, dict) or evidence.get("status") not in OPEN:
        errors.append(f"{label}.connectivity_evidence.status must remain open")
    for key in ("native_render", "human_route_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"route_runtime", "native_render", "human_route_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_SETTLEMENT_CONNECTIVITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SETTLEMENT_CONNECTIVITY_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
