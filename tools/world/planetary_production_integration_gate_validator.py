#!/usr/bin/env python3
"""Validate the detached planetary production-integration gate record.

This validator joins the already-authored world, Main/GameFlow, route,
objective/reward, and save/re-entry evidence IDs.  It is intentionally an
integration *gate*, not runtime wiring: it never starts Main, mutates
GameFlow, launches a package, or promotes detached evidence to a playtest.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_production_integration_gate"
EVIDENCE_MODE = "detached_contract_fixture"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_REGION_ID = "ember_caldera"
REQUIRED_RETURN_TARGET = "mudds_shipyards"

REQUIRED_GATES = (
    "world_identity",
    "main_gameflow_composition",
    "settlement_return_loop",
    "objective_reward_recovery",
    "save_reentry_divergence",
    "authority_boundary",
)
REQUIRED_OPEN_GATES = (
    "runtime_main_composition",
    "packaged_native_windows",
    "human_playthrough",
    "long_session_orbit_surface",
)
REQUIRED_AUTHORITY_OWNERS = {
    "activity": "activity_director",
    "reward": "game_flow_reward_authority",
    "recovery": "planetary_landing_return_contract",
    "origin": "common_world_origin_rebase_owner",
    "streaming": "planetary_origin_stream_contract",
    "save": "planetary_save_session_contract",
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_gate_record(value: Any, label: str = "gate") -> list[str]:
    """Return blocking errors for one detached integration gate record."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("production_wiring", "runtime_authority", "native_claims", "human_playtest_claims"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false for detached evidence")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision must be non-empty text")

    identity = value.get("identity")
    if not isinstance(identity, dict):
        errors.append(f"{label}.identity must be an object")
    else:
        for key, expected in (
            ("world_id", REQUIRED_WORLD_ID),
            ("landing_region_id", REQUIRED_REGION_ID),
            ("return_target_id", REQUIRED_RETURN_TARGET),
        ):
            if identity.get(key) != expected:
                errors.append(f"{label}.identity.{key} must be {expected}")

    gates = value.get("gates")
    if not isinstance(gates, list):
        errors.append(f"{label}.gates must be an array")
        gates = []
    gate_ids: list[str] = []
    for index, gate in enumerate(gates):
        prefix = f"{label}.gates[{index}]"
        if not isinstance(gate, dict):
            errors.append(f"{prefix} must be an object")
            continue
        gate_id = gate.get("id")
        if not _text(gate_id):
            errors.append(f"{prefix}.id is required")
            continue
        if gate_id in gate_ids:
            errors.append(f"{prefix}.id must be unique")
        gate_ids.append(gate_id)
        if gate.get("status") != "DETACHED_EVIDENCE":
            errors.append(f"{prefix}.status must be DETACHED_EVIDENCE")
        if not _text(gate.get("evidence_ref")) or not gate["evidence_ref"].startswith("res://"):
            errors.append(f"{prefix}.evidence_ref must be a res:// path")
        if gate.get("runtime_proven") is not False:
            errors.append(f"{prefix}.runtime_proven must be false")
        if gate.get("native_proven") is not False:
            errors.append(f"{prefix}.native_proven must be false")
        if gate.get("authority_mutated") is not False:
            errors.append(f"{prefix}.authority_mutated must be false")
    if tuple(gate_ids) != REQUIRED_GATES:
        errors.append(f"{label}.gates must contain the exact ordered planetary integration gate roster")

    owners = value.get("authority_owners")
    if not isinstance(owners, dict):
        errors.append(f"{label}.authority_owners must be an object")
    else:
        if set(owners) != set(REQUIRED_AUTHORITY_OWNERS):
            errors.append(f"{label}.authority_owners must contain the exact authority roster")
        for authority, owner in REQUIRED_AUTHORITY_OWNERS.items():
            if owners.get(authority) != owner:
                errors.append(f"{label}.authority_owners.{authority} must be {owner}")
        if len(set(owners.values())) != len(owners.values()):
            errors.append(f"{label}.authority_owners must not assign duplicate owners")

    composition = value.get("composition_limits")
    if not isinstance(composition, dict):
        errors.append(f"{label}.composition_limits must be an object")
    else:
        for key in (
            "main_instance_count", "game_flow_instance_count", "origin_owner_count",
            "streaming_binding_count", "surface_loop_binding_count", "reward_store_count",
        ):
            if composition.get(key) != 1:
                errors.append(f"{label}.composition_limits.{key} must be exactly one")
        if composition.get("active_location_count") != 1:
            errors.append(f"{label}.composition_limits.active_location_count must be one authored location")
        if composition.get("travel_session_count") != 0:
            errors.append(f"{label}.composition_limits.travel_session_count must be zero")
        for key in ("duplicate_mover", "duplicate_origin_owner", "actor_reparented", "final_approach_teleport"):
            if composition.get(key) is not False:
                errors.append(f"{label}.composition_limits.{key} must be false")

    open_gates = value.get("open_gates")
    if not isinstance(open_gates, list):
        errors.append(f"{label}.open_gates must be an array")
        open_gates = []
    open_ids: list[str] = []
    for index, open_gate in enumerate(open_gates):
        prefix = f"{label}.open_gates[{index}]"
        if not isinstance(open_gate, dict):
            errors.append(f"{prefix} must be an object")
            continue
        gate_id = open_gate.get("id")
        if not _text(gate_id):
            errors.append(f"{prefix}.id is required")
            continue
        if gate_id in open_ids:
            errors.append(f"{prefix}.id must be unique")
        open_ids.append(gate_id)
        if open_gate.get("status") != "OPEN":
            errors.append(f"{prefix}.status must be OPEN")
        if open_gate.get("completion_proven") is not False:
            errors.append(f"{prefix}.completion_proven must be false")
        if not _text(open_gate.get("reason")):
            errors.append(f"{prefix}.reason is required")
    if tuple(open_ids) != REQUIRED_OPEN_GATES:
        errors.append(f"{label}.open_gates must keep native, human, packaged, and long-session gates open")

    return errors


def summarize(value: dict[str, Any]) -> dict[str, Any]:
    """Expose gate counts while retaining the detached/open distinction."""

    return {
        "world_id": value["identity"]["world_id"],
        "landing_region_id": value["identity"]["landing_region_id"],
        "gate_count": len(value["gates"]),
        "open_gate_count": len(value["open_gates"]),
        "production_wiring": value["production_wiring"],
        "native_claims": value["native_claims"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gate_record", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.gate_record.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_INTEGRATION_GATE_INVALID: {exc}")
        return 1
    errors = validate_gate_record(report)
    if errors:
        print("PLANETARY_INTEGRATION_GATE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(json.dumps(summarize(report), indent=2, sort_keys=True))
    print("PLANETARY_INTEGRATION_GATE_VALID: detached evidence only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
