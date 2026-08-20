#!/usr/bin/env python3
"""Validate the fleet's bounded physical boarding/interior interaction manifest.

This is an evidence/acceptance manifest, not runtime authority.  It checks that
each live craft has a differentiated role and readable silhouette, that the
focused production tests cover a physical walk-up boarding route and cockpit,
and that the larger craft publish a connected interior route.  Historical
status is checked independently from playable geometry so an implementation or
green test cannot authenticate an unknown original craft.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
REPORT_KIND = "fleet_craft_physical_interaction"
CLAIM_SCOPE = "runtime_acceptance_contract_not_historical_authentication"
EXPECTED_SHIPS = {
    "torrent_provisional",
    "arrow_provisional",
    "jovian_provisional",
    "zenith_b7_observed",
    "halyard_new_design",
}
SMALL_BANDS = {"small"}
MEDIUM_BANDS = {"medium"}
EVIDENCE_STATUSES = {"provisional", "new"}
NAME_TO_MODEL_STATUSES = {
    "bounded_partial_reconstruction",
    "unknown",
    "modern_interpretation",
}
SILHOUETTE_CLAIMS = {"bounded_partial", "modern_interpretation"}
REQUIRED_ROUTE_MARKERS = {"exterior_access", "interior_deck", "pilot_seat"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _positive(value: Any) -> bool:
    return _number(value) and value > 0


def _errors_for_ship(ship: Any, index: int, manifest: dict[str, Any]) -> list[str]:
    label = f"ships[{index}]"
    errors: list[str] = []
    if not isinstance(ship, dict):
        return [f"{label} must be an object"]
    for key in ("ship_id", "role", "role_tag", "scale_band", "evidence_status", "name_to_model_status"):
        if not _text(ship.get(key)):
            errors.append(f"{label}.{key} is required")
    if ship.get("scale_band") not in SMALL_BANDS | MEDIUM_BANDS:
        errors.append(f"{label}.scale_band must be small or medium")
    if ship.get("evidence_status") not in EVIDENCE_STATUSES:
        errors.append(f"{label}.evidence_status must be one of {sorted(EVIDENCE_STATUSES)}")
    if ship.get("name_to_model_status") not in NAME_TO_MODEL_STATUSES:
        errors.append(f"{label}.name_to_model_status is not a supported historical status")

    refs = ship.get("evidence_references")
    if not isinstance(refs, list) or any(not _text(ref) for ref in refs):
        errors.append(f"{label}.evidence_references must be an array of non-empty strings")
    if ship.get("evidence_status") == "new" and refs:
        errors.append(f"{label}.new design cannot attach historical evidence references")
    if ship.get("evidence_status") == "new" and ship.get("name_to_model_status") != "modern_interpretation":
        errors.append(f"{label}.new design must remain modern_interpretation")
    if ship.get("evidence_status") == "provisional" and not refs:
        errors.append(f"{label}.provisional candidate needs a source/evidence note")
    if ship.get("name_to_model_status") == "bounded_partial_reconstruction" and not refs:
        errors.append(f"{label}.bounded partial reconstruction needs evidence references")

    silhouette = ship.get("silhouette")
    if not isinstance(silhouette, dict):
        errors.append(f"{label}.silhouette must be an object")
    else:
        for key in ("family", "claim", "source"):
            if not _text(silhouette.get(key)):
                errors.append(f"{label}.silhouette.{key} is required")
        for key in ("width_m", "length_m"):
            if not _positive(silhouette.get(key)):
                errors.append(f"{label}.silhouette.{key} must be positive")
        if silhouette.get("claim") not in SILHOUETTE_CLAIMS:
            errors.append(f"{label}.silhouette.claim is unsupported")
        if ship.get("name_to_model_status") == "unknown" and silhouette.get("claim") != "modern_interpretation":
            errors.append(f"{label}.unknown name-to-model mapping cannot claim bounded silhouette")

    boarding = ship.get("boarding")
    if not isinstance(boarding, dict):
        errors.append(f"{label}.boarding must be an object")
    else:
        if boarding.get("physical") is not True:
            errors.append(f"{label}.boarding.physical must be true")
        for key in ("entry_anchor", "approach_route", "focused_test"):
            if not _text(boarding.get(key)):
                errors.append(f"{label}.boarding.{key} is required")
        for key in ("staged_beyond_fallback_reach", "route_clear", "prompt_after_walk"):
            if boarding.get(key) is not True:
                errors.append(f"{label}.boarding.{key} must be true")
        minimum_walk = boarding.get("minimum_walk_m")
        manifest_minimum_walk = manifest.get("minimum_walk_m")
        if not _number(minimum_walk) or minimum_walk < float(manifest_minimum_walk):
            errors.append(f"{label}.boarding.minimum_walk_m must meet manifest floor")
        if not _number(boarding.get("grounded_ticks_required")) or boarding["grounded_ticks_required"] < 1:
            errors.append(f"{label}.boarding.grounded_ticks_required must be at least one")

    cockpit = ship.get("cockpit")
    if not isinstance(cockpit, dict):
        errors.append(f"{label}.cockpit must be an object")
    else:
        for key in ("pilot_seat_anchor", "camera_anchor"):
            if not _text(cockpit.get(key)):
                errors.append(f"{label}.cockpit.{key} is required")
        if cockpit.get("pilot_seats") != 1:
            errors.append(f"{label}.cockpit.pilot_seats must be exactly one for the current fleet contract")
        if cockpit.get("seat_to_camera_rise_m") != manifest.get("seat_to_cockpit_camera_rise_m"):
            errors.append(f"{label}.cockpit.seat_to_camera_rise_m must match frozen fleet convention")
        if not _number(cockpit.get("head_hull_clearance_m")) or cockpit["head_hull_clearance_m"] < manifest.get("minimum_head_hull_clearance_m", 0):
            errors.append(f"{label}.cockpit.head_hull_clearance_m is below the frozen safety floor")

    interior = ship.get("interior")
    if not isinstance(interior, dict):
        errors.append(f"{label}.interior must be an object")
    else:
        walkable = interior.get("walkable") is True
        if walkable:
            if ship.get("scale_band") != "medium":
                errors.append(f"{label}.walkable interior requires medium scale band")
            if interior.get("connected_to_ship_frame") is not True:
                errors.append(f"{label}.walkable interior must be connected to the ship frame")
            if not _text(interior.get("root")):
                errors.append(f"{label}.walkable interior.root is required")
            markers = interior.get("route_markers")
            if not isinstance(markers, list) or not REQUIRED_ROUTE_MARKERS.issubset(markers):
                errors.append(f"{label}.walkable interior route must cover {sorted(REQUIRED_ROUTE_MARKERS)}")
            if not _number(interior.get("passenger_seats")) or interior["passenger_seats"] < 4:
                errors.append(f"{label}.walkable interior needs a passenger complement")
            if interior.get("moving_interior_frame") is not True:
                errors.append(f"{label}.walkable interior must publish moving-interior frame coverage")
            dimensions = interior.get("dimensions_m")
            if not isinstance(dimensions, list) or len(dimensions) != 3 or any(not _positive(value) for value in dimensions):
                errors.append(f"{label}.walkable interior.dimensions_m must contain three positive dimensions")
            if not _positive(interior.get("volume_m3")) or interior.get("volume_m3", 0) < 300.0:
                errors.append(f"{label}.walkable interior.volume_m3 must be at least 300")
        else:
            if interior.get("connected_to_ship_frame") is not False:
                errors.append(f"{label}.non-walkable craft must not claim a connected interior")
            if interior.get("route_markers") not in ([], None):
                errors.append(f"{label}.non-walkable craft cannot publish interior route markers")
            if interior.get("passenger_seats") != 0:
                errors.append(f"{label}.non-walkable craft must have zero passenger seats")
            if interior.get("moving_interior_frame") is not False:
                errors.append(f"{label}.non-walkable craft cannot publish moving-interior frame coverage")
            silhouette = ship.get("silhouette", {})
            if isinstance(silhouette, dict):
                horizontal_max = max(float(silhouette.get("width_m", 0)), float(silhouette.get("length_m", 0)))
                if horizontal_max > float(manifest.get("small_craft_envelope_maximum_m", 15.0)):
                    errors.append(f"{label}.non-walkable craft exceeds the small-craft envelope")
    return errors


def validate_manifest(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the manifest is valid."""
    if not isinstance(value, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if value.get("report_kind") != REPORT_KIND:
        errors.append(f"report_kind must be {REPORT_KIND}")
    if value.get("claim_scope") != CLAIM_SCOPE:
        errors.append(f"claim_scope must be {CLAIM_SCOPE}")
    if not _text(value.get("source_of_runtime_facts")) or not _text(value.get("source_of_visual_grammar")):
        errors.append("runtime and visual-grammar sources are required")
    ships = value.get("ships")
    if not isinstance(ships, list) or not ships:
        return errors + ["ships must be a non-empty array"]
    ids = [ship.get("ship_id") for ship in ships if isinstance(ship, dict)]
    if len(ids) != len(set(ids)):
        errors.append("ships.ship_id values must be unique")
    if set(ids) != EXPECTED_SHIPS:
        errors.append(f"ships must exactly cover the current five-craft roster {sorted(EXPECTED_SHIPS)}")
    roles = [ship.get("role") for ship in ships if isinstance(ship, dict)]
    if len(roles) != len(set(roles)):
        errors.append("ships.role values must be unique")
    for index, ship in enumerate(ships):
        errors.extend(_errors_for_ship(ship, index, value))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"FLEET_CRAFT_INTERACTION_INVALID: {exc}")
        return 1
    errors = validate_manifest(value)
    if errors:
        print("FLEET_CRAFT_INTERACTION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("FLEET_CRAFT_INTERACTION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
