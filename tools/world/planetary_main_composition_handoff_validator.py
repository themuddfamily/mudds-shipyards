#!/usr/bin/env python3
"""Validate a detached Main/GameFlow planetary composition handoff.

The handoff is an evidence record for the future production seam.  It checks
that Main retains one copy of each existing authority and that GameFlow's
sample/origin/loop/return sequence is explicit.  It never instantiates Godot,
loads Main, moves actors, samples input, or claims a native playthrough.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_main_gameflow_composition_handoff"
EVIDENCE_MODE = "detached_contract_fixture"
REQUIRED_SCENE = "res://scenes/main.tscn"

REQUIRED_OWNER_IDS = (
    "main",
    "game_flow",
    "player_controller",
    "hero_ship",
    "coordinate_frame",
    "origin_owner",
    "streaming_binding",
    "surface_loop_binding",
    "landing_return_contract",
)

REQUIRED_AUTHORITY_OWNERS = {
    "composition": "main",
    "phase": "game_flow",
    "player_movement": "player_controller",
    "ship_motion": "hero_ship",
    "coordinate_frame": "coordinate_frame",
    "origin_shift": "origin_owner",
    "streaming_observation": "streaming_binding",
    "surface_loop": "surface_loop_binding",
    "landing_return": "landing_return_contract",
}

REQUIRED_HANDOFFS = (
    "actor_sample",
    "origin_receipt",
    "surface_loop_start_or_advance",
    "completion_handback",
)

REQUIRED_PHASES = (
    "orbit_approach",
    "descent",
    "surface_flight",
    "landed",
    "on_foot",
    "reboarded",
    "takeoff",
    "orbit_return",
)

FORBIDDEN_DUPLICATION_GUARDS = (
    "duplicate_mover",
    "duplicate_origin_owner",
    "duplicate_streaming_coordinator",
    "duplicate_planetary_travel_session",
    "teleport_final_approach",
    "reparent_retained_actor",
    "raw_input_in_binding",
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _validate_owner_roster(value: Any, errors: list[str]) -> None:
    if not isinstance(value, list):
        errors.append("owners must be an array")
        return
    ids: list[str] = []
    for index, owner in enumerate(value):
        prefix = f"owners[{index}]"
        if not isinstance(owner, dict):
            errors.append(f"{prefix} must be an object")
            continue
        owner_id = owner.get("id")
        if not _text(owner_id):
            errors.append(f"{prefix}.id is required")
            continue
        if owner_id in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.append(owner_id)
        if not _text(owner.get("path")):
            errors.append(f"{prefix}.path is required")
        if not _text(owner.get("role")):
            errors.append(f"{prefix}.role is required")
        if owner.get("instance_count") != 1:
            errors.append(f"{prefix}.instance_count must be exactly one")
        authorities = owner.get("authorities")
        if not isinstance(authorities, list) or not authorities:
            errors.append(f"{prefix}.authorities must contain at least one authority")
    if tuple(ids) != REQUIRED_OWNER_IDS:
        errors.append("owners must contain the exact Main/GameFlow composition roster in order")


def _validate_authority_roster(value: Any, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append("authority_owners must be an object")
        return
    if set(value) != set(REQUIRED_AUTHORITY_OWNERS):
        errors.append("authority_owners must contain the exact non-overlapping authority roster")
    for authority, expected_owner in REQUIRED_AUTHORITY_OWNERS.items():
        if value.get(authority) != expected_owner:
            errors.append(f"authority_owners.{authority} must be owned by {expected_owner}")


def _validate_handoffs(value: Any, errors: list[str]) -> None:
    if not isinstance(value, list):
        errors.append("handoffs must be an array")
        return
    names: list[str] = []
    sequences: list[int] = []
    for index, handoff in enumerate(value):
        prefix = f"handoffs[{index}]"
        if not isinstance(handoff, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = handoff.get("name")
        if not _text(name):
            errors.append(f"{prefix}.name is required")
        elif name in names:
            errors.append(f"{prefix}.name must be unique")
        names.append(name)
        if not _text(handoff.get("from")) or not _text(handoff.get("to")):
            errors.append(f"{prefix} requires from and to owners")
        if handoff.get("accepted") is not True:
            errors.append(f"{prefix}.accepted must be true")
        if not _non_negative_int(handoff.get("sequence")):
            errors.append(f"{prefix}.sequence must be a non-negative integer")
        else:
            sequences.append(handoff["sequence"])
        if handoff.get("same_physics_tick") is not True:
            errors.append(f"{prefix}.same_physics_tick must be true")
        if handoff.get("mutates_source_owner") is not False:
            errors.append(f"{prefix}.mutates_source_owner must be false")
    if tuple(names) != REQUIRED_HANDOFFS:
        errors.append("handoffs must follow the required actor-to-return sequence")
    if sequences != list(range(len(sequences))):
        errors.append("handoffs.sequence must start at zero and increase by one")


def _validate_lifecycle(value: Any, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append("lifecycle must be an object")
        return
    if value.get("same_main_instance_on_detach_reentry") is not True:
        errors.append("lifecycle.same_main_instance_on_detach_reentry must be true")
    if value.get("generation_preserved_on_detach_reentry") is not True:
        errors.append("lifecycle.generation_preserved_on_detach_reentry must be true")
    if value.get("actor_reparented") is not False:
        errors.append("lifecycle.actor_reparented must be false")
    if value.get("stale_handoff_rejected") is not True:
        errors.append("lifecycle.stale_handoff_rejected must be true")
    if not _positive_int(value.get("composition_generation")):
        errors.append("lifecycle.composition_generation must be positive")
    if not _positive_int(value.get("main_instance_id")):
        errors.append("lifecycle.main_instance_id must be positive")


def validate_handoff(value: Any, label: str = "handoff") -> list[str]:
    """Return blocking errors; an empty list means the detached handoff is valid."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    if value.get("production_wiring") is not False:
        errors.append(f"{label}.production_wiring must be false until Main/GameFlow composition is live")
    if value.get("native_claims") is not False:
        errors.append(f"{label}.native_claims must be false for a detached handoff")
    if value.get("scene_path") != REQUIRED_SCENE:
        errors.append(f"{label}.scene_path must be {REQUIRED_SCENE}")

    _validate_owner_roster(value.get("owners"), errors)
    _validate_authority_roster(value.get("authority_owners"), errors)
    _validate_handoffs(value.get("handoffs"), errors)
    _validate_lifecycle(value.get("lifecycle"), errors)

    phases = value.get("phase_path")
    if not isinstance(phases, list) or tuple(phases) != REQUIRED_PHASES:
        errors.append(f"{label}.phase_path must contain the bounded planetary phase path")

    guards = value.get("negative_guards")
    if not isinstance(guards, dict):
        errors.append(f"{label}.negative_guards must be an object")
    else:
        for guard in FORBIDDEN_DUPLICATION_GUARDS:
            if guards.get(guard) is not False:
                errors.append(f"{label}.negative_guards.{guard} must be false")
    return errors


def summarize(value: dict[str, Any]) -> dict[str, Any]:
    """Return detached headline values without changing the acceptance gate."""

    return {
        "scene_path": value["scene_path"],
        "owner_count": len(value["owners"]),
        "handoff_count": len(value["handoffs"]),
        "phase_count": len(value["phase_path"]),
        "composition_generation": value["lifecycle"]["composition_generation"],
        "production_wiring": value["production_wiring"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("handoff", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.handoff.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_MAIN_COMPOSITION_HANDOFF_INVALID: {exc}")
        return 1
    errors = validate_handoff(value)
    if errors:
        print("PLANETARY_MAIN_COMPOSITION_HANDOFF_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(json.dumps(summarize(value), indent=2, sort_keys=True))
    print("PLANETARY_MAIN_COMPOSITION_HANDOFF_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
