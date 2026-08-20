#!/usr/bin/env python3
"""Validate the production runtime-remap/conflict handoff.

This ledger joins the detached remap contract to GameFlow's five retained
ship-local input sources.  It proves only that the handoff is described
completely; hardware, InputMap devices, and native production runs remain
external gates.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "runtime_remap_production_handoff_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
ITEM_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
CONFLICT_POLICIES = ("reject", "replace")
SHIP_IDS = (
    "torrent_provisional", "arrow_provisional", "jovian_provisional",
    "zenith_b7_observed", "halyard_new_design",
)
GAMEPLAY_ACTIONS = (
    "move_forward", "move_back", "move_left", "move_right", "pitch_up",
    "pitch_down", "roll_left", "roll_right", "jump", "sprint_boost",
    "interact", "hover", "fire", "barrel_roll", "landing_assist",
    "toggle_ship_camera_view", "camera_distance_in", "camera_distance_out",
    "brake", "pause", "toggle_controls_overlay", "toggle_first_person",
)
REQUIRED_CASES = (
    "startup_apply_all_fleet_sources", "reject_conflict_atomic",
    "replace_conflict_atomic", "reject_invalid_atomic", "reject_stale_generation",
    "no_op_profile_reclaim", "reentry_retain_generations", "input_map_applies_once",
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _references(value: Any, prefix: str, errors: list[str], *, allow_none: bool) -> None:
    if value is None and allow_none:
        return
    if not isinstance(value, list) or not value:
        errors.append(f"{prefix} must be null while pending or a non-empty evidence list")
        return
    seen: set[tuple[str, str]] = set()
    for index, reference in enumerate(value):
        label = f"{prefix}[{index}]"
        if not isinstance(reference, dict):
            errors.append(f"{label} must be an object")
            continue
        if reference.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{label}.kind must be log, video, image, or report")
        if not _text(reference.get("path")):
            errors.append(f"{label}.path must be non-empty text")
        if not _sha(reference.get("sha256")):
            errors.append(f"{label}.sha256 must be a lowercase digest")
        path, digest = reference.get("path"), reference.get("sha256")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier reference")
            seen.add(identity)


def _validate_sources(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["fleet_sources must contain exactly five retained ship input sources"]
    if len(value) != len(SHIP_IDS):
        errors.append("fleet_sources must contain exactly five retained ship input sources")
    ids: list[str] = []
    for index, source in enumerate(value):
        prefix = f"fleet_sources[{index}]"
        if not isinstance(source, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ship_id = source.get("ship_id")
        if ship_id not in SHIP_IDS:
            errors.append(f"{prefix}.ship_id must be one of the five production ShipDefinition IDs")
        else:
            ids.append(ship_id)
        if source.get("source_kind") != "LocalShipInputSource":
            errors.append(f"{prefix}.source_kind must be LocalShipInputSource")
        if source.get("exact_action_roster") is not True:
            errors.append(f"{prefix}.exact_action_roster must be true")
        if source.get("generation_guarded") is not True:
            errors.append(f"{prefix}.generation_guarded must be true")
        status = source.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        _references(
            source.get("evidence"),
            f"{prefix}.evidence",
            errors,
            allow_none=isinstance(status, str) and status in {"planned", "pending"},
        )
    if len(ids) != len(set(ids)):
        errors.append("fleet_sources.ship_id values must be unique")
    if tuple(ids) != SHIP_IDS:
        errors.append("fleet_sources must exactly match the frozen production fleet order")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly eight production remap handoff cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly eight production remap handoff cases")
    ids: list[str] = []
    seen_evidence: set[tuple[str, str]] = set()
    for index, case in enumerate(value):
        prefix = f"cases[{index}]"
        if not isinstance(case, dict):
            errors.append(f"{prefix} must be an object")
            continue
        case_id = case.get("id")
        if not _text(case_id):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(case_id)
        for key in ("expected", "production_owner", "detached_contract_test"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        status = case.get("status")
        if not isinstance(status, str) or status not in ITEM_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        evidence = case.get("evidence")
        _references(
            evidence,
            f"{prefix}.evidence",
            errors,
            allow_none=isinstance(status, str) and status in {"planned", "pending"},
        )
        if isinstance(evidence, list):
            for reference in evidence:
                if not isinstance(reference, dict):
                    continue
                path, digest = reference.get("path"), reference.get("sha256")
                if isinstance(path, str) and isinstance(digest, str) and _sha(digest):
                    identity = (path, digest)
                    if identity in seen_evidence:
                        errors.append(f"{prefix}.evidence duplicates an earlier ledger reference")
                    seen_evidence.add(identity)
    if len(ids) != len(set(ids)):
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen production remap coverage order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for external hardware review."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("production_handoff_status") not in OPEN_STATUSES:
        errors.append("production_handoff_status must remain pending, not_performed, in_progress, or failed")
    if value.get("hardware_validation_status") not in {"not_run", "planned", "blocked"}:
        errors.append("hardware_validation_status must remain not_run, planned, or blocked")
    for key in ("source_revision", "contract_source", "production_owner", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key, expected in (
        ("hardware_run_performed", False),
        ("detached_contract_tests_only", True),
        ("runtime_authority_unchanged", True),
    ):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("conflict_policies") != list(CONFLICT_POLICIES):
        errors.append("conflict_policies must exactly match reject, replace")
    roster = value.get("action_roster")
    if not isinstance(roster, dict):
        errors.append("action_roster must be an object")
    else:
        if roster.get("required_actions") != list(GAMEPLAY_ACTIONS):
            errors.append("action_roster.required_actions must match the production gameplay roster")
        if roster.get("covered_actions") != list(GAMEPLAY_ACTIONS):
            errors.append("action_roster.covered_actions must preserve the production gameplay roster")
    errors.extend(_validate_sources(value.get("fleet_sources")))
    errors.extend(_validate_cases(value.get("cases")))
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
        print("RUNTIME_REMAP_PRODUCTION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("RUNTIME_REMAP_PRODUCTION_READY: hardware validation remains external")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
