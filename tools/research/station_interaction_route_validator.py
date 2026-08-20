"""Validate the station's bounded interaction-route evidence tables.

``STATION_TOPOLOGY.md`` is a confidence-graded floor-plan record, not a
runtime authority.  This gate checks the machine-marked live tables that sit
between the route registry and the human interaction/playability suites:

* every edge's connection marker is present in its module route roster;
* every route roster is unique and every declared dead-end is explicitly
  represented by the non-slot landmark table;
* deferred/external landmarks retain an explicit no-slot/no-authority gate;
* the document keeps the important boundary that declared adjacency is not
  proof of physical reachability and that this evidence pass does not mutate
  topology.

The validator intentionally does not instantiate Godot, calculate distances,
or infer a walkable path from coordinates.  Runtime reachability remains the
responsibility of ``StationInteractionContract`` and the production traversal
suites; this file prevents the research document from silently overclaiming
those results.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any


MARKERS = (
    "LIVE-GRAPH-TOTALS",
    "LIVE-GRAPH-EDGES",
    "LIVE-GRAPH-ROUTES",
    "LIVE-GRAPH-DEFERRED",
)
REQUIRED_TOTALS = frozenset(
    {
        "module_count",
        "hub_endpoint_count",
        "connection_slot_count",
        "edge_count",
        "route_marker_count",
        "resolved_route_marker_count",
        "dangling_slot_count",
        "overclaimed_slot_count",
        "authority_claim_count",
        "production_berth_count",
        "deferred_or_dead_end_route_marker_count",
    }
)
_INTEGER = re.compile(r"^-?\d+$")


def _unquote(value: str) -> str:
    return value.strip().replace("`", "")


def _rows(text: str, marker: str) -> list[list[str]]:
    begin = text.find(f"<!-- {marker}:BEGIN -->")
    end = text.find(f"<!-- {marker}:END -->")
    if begin < 0 or end <= begin:
        return []
    block = text[begin + len(f"<!-- {marker}:BEGIN -->") : end]
    table: list[list[str]] = []
    for raw_line in block.splitlines():
        line = raw_line.strip()
        if not line.startswith("|"):
            continue
        cells = [_unquote(cell) for cell in line.strip("|").split("|")]
        if not any(cells):
            continue
        # Markdown separator cells contain only hyphens and optional colons.
        if all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        table.append(cells)
    return table[1:] if table else []


def _split_list(value: str) -> list[str]:
    value = value.strip()
    if not value or value == "—":
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def parse_document(text: str) -> dict[str, Any]:
    """Parse the four marker-delimited tables without interpreting prose."""

    totals: dict[str, int] = {}
    for row in _rows(text, "LIVE-GRAPH-TOTALS"):
        if len(row) >= 2 and _INTEGER.fullmatch(row[1]):
            totals[row[0]] = int(row[1])

    edges: list[dict[str, str]] = []
    for row in _rows(text, "LIVE-GRAPH-EDGES"):
        if len(row) >= 5:
            edges.append(
                {
                    "slot_id": row[0],
                    "hub_anchor": row[1],
                    "module_id": row[2],
                    "route_id": row[3],
                    "evidence_status": row[4],
                }
            )

    routes: list[dict[str, Any]] = []
    for row in _rows(text, "LIVE-GRAPH-ROUTES"):
        if len(row) >= 4:
            routes.append(
                {
                    "module_id": row[0],
                    "routes": _split_list(row[1]),
                    "connection_route": row[2],
                    "dead_ends": _split_list(row[3]),
                }
            )

    deferred: list[dict[str, str]] = []
    for row in _rows(text, "LIVE-GRAPH-DEFERRED"):
        if len(row) >= 5:
            deferred.append(
                {
                    "landmark": row[0],
                    "module_id": row[1],
                    "route_id": row[2],
                    "origin": row[3],
                    "gate": row[4],
                }
            )
    return {"totals": totals, "edges": edges, "routes": routes, "deferred": deferred}


def validate_document(path: str | Path) -> list[str]:
    """Return fail-closed errors for the station interaction evidence."""

    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as exc:
        return [f"topology document cannot be read: {exc}"]
    errors: list[str] = []
    for marker in MARKERS:
        if f"<!-- {marker}:BEGIN -->" not in text or f"<!-- {marker}:END -->" not in text:
            errors.append(f"missing complete {marker} table")

    parsed = parse_document(text)
    totals = parsed["totals"]
    missing_totals = sorted(REQUIRED_TOTALS - totals.keys())
    if missing_totals:
        errors.append(f"missing live totals: {', '.join(missing_totals)}")
    if any(value < 0 for value in totals.values()):
        errors.append("live totals cannot be negative")

    edges = parsed["edges"]
    routes = parsed["routes"]
    deferred = parsed["deferred"]
    route_by_module = {row["module_id"]: row for row in routes}
    if len(route_by_module) != len(routes):
        errors.append("module route roster contains duplicate module IDs")
    edge_slots = [row["slot_id"] for row in edges]
    if len(set(edge_slots)) != len(edge_slots):
        errors.append("live edge table contains duplicate connection slots")
    edge_modules = [row["module_id"] for row in edges]
    if len(set(edge_modules)) != len(edge_modules):
        errors.append("live edge table contains duplicate module endpoints")

    all_route_keys: set[tuple[str, str]] = set()
    connection_keys: set[tuple[str, str]] = set()
    dead_end_keys: set[tuple[str, str]] = set()
    for route in routes:
        module_id = route["module_id"]
        marker_ids = route["routes"]
        if not module_id or not marker_ids:
            errors.append(f"module {module_id or '<empty>'} must publish route markers")
        if len(set(marker_ids)) != len(marker_ids):
            errors.append(f"module {module_id or '<empty>'} contains duplicate route markers")
        for marker_id in marker_ids:
            key = (module_id, marker_id)
            if key in all_route_keys:
                errors.append(f"route marker is published more than once: {module_id}/{marker_id}")
            all_route_keys.add(key)
        connection_route = route["connection_route"]
        if connection_route not in marker_ids:
            errors.append(f"{module_id} connection marker is absent from its route roster")
        else:
            connection_keys.add((module_id, connection_route))
        for marker_id in route["dead_ends"]:
            key = (module_id, marker_id)
            dead_end_keys.add(key)
            if key not in all_route_keys:
                errors.append(f"{module_id} dead-end marker is absent from its route roster: {marker_id}")
            if marker_id == connection_route:
                errors.append(f"{module_id} connection marker cannot also be a dead end: {marker_id}")

    for edge in edges:
        module_id = edge["module_id"]
        route_id = edge["route_id"]
        route = route_by_module.get(module_id)
        if route is None:
            errors.append(f"edge {edge['slot_id']} references unregistered module {module_id}")
            continue
        if route_id != route["connection_route"]:
            errors.append(f"edge {edge['slot_id']} does not use the module connection marker")
        if (module_id, route_id) not in all_route_keys:
            errors.append(f"edge {edge['slot_id']} references missing route marker {module_id}/{route_id}")
        if not edge["hub_anchor"] or not edge["evidence_status"]:
            errors.append(f"edge {edge['slot_id']} must publish hub anchor and bounded evidence status")
        if "modern_interpretation" not in edge["evidence_status"]:
            errors.append(f"edge {edge['slot_id']} evidence status must remain modern_interpretation-bounded")

    deferred_keys: set[tuple[str, str]] = set()
    for row in deferred:
        key = (row["module_id"], row["route_id"])
        deferred_keys.add(key)
        if key not in all_route_keys:
            errors.append(f"deferred landmark references missing route marker {row['module_id']}/{row['route_id']}")
        if key in connection_keys:
            errors.append(f"deferred landmark claims a connection marker: {row['module_id']}/{row['route_id']}")
        gate = row["gate"].casefold()
        if not row["origin"].strip():
            errors.append(f"deferred landmark has no world origin: {row['landmark']}")
        has_explicit_gate = any(
            token in gate for token in ("no station slot", "external berth", "deferred", "no graph edge")
        )
        # Open authored landmarks are allowed when the gate also labels the
        # destination as an interpretation; the surrounding graph prose still
        # keeps them outside adjacency.
        if not has_explicit_gate and not ("open" in gate and "modern_interpretation" in gate):
            errors.append(f"deferred landmark lacks explicit non-slot/deferred gate: {row['landmark']}")

    undocumented_dead_ends = sorted(dead_end_keys - deferred_keys)
    if undocumented_dead_ends:
        errors.append(
            "route dead ends missing from non-slot landmark table: "
            + ", ".join(f"{module}/{marker}" for module, marker in undocumented_dead_ends)
        )
    orphan_deferred = sorted(deferred_keys - dead_end_keys)
    if orphan_deferred:
        errors.append(
            "non-slot landmarks are not marked dead-end/deferred in route roster: "
            + ", ".join(f"{module}/{marker}" for module, marker in orphan_deferred)
        )

    # The document must state the epistemic boundary explicitly.  These guards
    # are the static counterpart of the live interaction contract: a registry
    # edge is not a walkable path, and this audit cannot mutate topology.
    if "Adjacency in the running world is **declared, not metric**" not in text:
        errors.append("document must state that adjacency is declared rather than metric")
    if "The registry proves declared topology only." not in text:
        errors.append("document must state that the registry does not prove physical reachability")
    normalized_text = " ".join(text.split())
    if "does not prove the player can walk any slot" not in normalized_text:
        errors.append("document must preserve the no-walkability-overclaim boundary")
    if "non-authoritative" not in text:
        errors.append("document must label non-slot interaction landmarks non-authoritative")

    # Reconcile declared totals with the parsed evidence rather than trusting a
    # stale number pasted into the report.
    expected = {
        "module_count": len(routes),
        "connection_slot_count": len(edges),
        "edge_count": len(edges),
        "route_marker_count": sum(len(route["routes"]) for route in routes),
        "resolved_route_marker_count": len(all_route_keys),
        "deferred_or_dead_end_route_marker_count": len(dead_end_keys),
    }
    for name, actual in expected.items():
        if name in totals and totals[name] != actual:
            errors.append(f"{name} total is {totals[name]}, but parsed evidence contains {actual}")
    return errors


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("document", type=Path)
    args = parser.parse_args()
    errors = validate_document(args.document)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("STATION_INTERACTION_ROUTE_EVIDENCE_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
