#!/usr/bin/env python3
"""Validate detached projectile and boarding authority evidence.

The rollup joins server projectile spawn/impact/damage receipts with a
generation-fenced boarding occupancy receipt. It checks that clients cannot
invent damage, moving-frame identity, or occupancy state. No combat, physics,
scene, or live network is run by this evidence gate.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_projectile_boarding_authority"
EVIDENCE_MODE = "detached_contract_fixture"
PROJECTILE_POLICY = "network_projectile_damage_authority_v1"
BOARDING_POLICY = "network_boarding_occupancy_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _non_negative_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value)) and value >= 0


def validate_rollup(report: Any, label: str = "rollup") -> list[str]:
    """Return projectile/boarding authority errors for one rollup."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("projectile_policy", PROJECTILE_POLICY),
        ("boarding_policy", BOARDING_POLICY),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network", "simulates_physics"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    projectile_audit = report.get("projectile_audit")
    if not isinstance(projectile_audit, dict):
        errors.append(f"{label}.projectile_audit must be an object")
    else:
        for key in ("server_owns_projectile_spawn", "server_owns_projectile_motion", "server_owns_damage_amount"):
            if projectile_audit.get(key) is not True:
                errors.append(f"{label}.projectile_audit.{key} must be true")
        for key in ("server_owns_health_store", "client_can_mutate_projectiles"):
            if projectile_audit.get(key) is not False:
                errors.append(f"{label}.projectile_audit.{key} must be false")
    boarding_audit = report.get("boarding_audit")
    if not isinstance(boarding_audit, dict):
        errors.append(f"{label}.boarding_audit must be an object")
    else:
        for key in ("server_owns_boarding", "server_owns_seat_occupancy", "server_owns_frame_binding", "one_seat_per_avatar", "one_avatar_per_seat"):
            if boarding_audit.get(key) is not True:
                errors.append(f"{label}.boarding_audit.{key} must be true")
        for key in ("client_can_mutate_occupancy", "owns_movement", "owns_ship_simulation"):
            if boarding_audit.get(key) is not False:
                errors.append(f"{label}.boarding_audit.{key} must be false")

    spawn = report.get("projectile_spawn")
    if not isinstance(spawn, dict):
        errors.append(f"{label}.projectile_spawn must be an object")
        spawn = {}
    if spawn.get("accepted") is not True or spawn.get("status") != "spawned":
        errors.append(f"{label}.projectile_spawn must be an accepted spawned receipt")
    if spawn.get("server_committed") is not True:
        errors.append(f"{label}.projectile_spawn.server_committed must be true")
    for key in ("projectile_id", "source_entity_id"):
        if not isinstance(spawn.get(key), str) or not spawn[key].strip():
            errors.append(f"{label}.projectile_spawn.{key} must be non-empty")
    for key in ("owner_peer_id", "source_generation", "projectile_generation"):
        if not _positive_int(spawn.get(key)):
            errors.append(f"{label}.projectile_spawn.{key} must be positive")

    impact = report.get("projectile_impact")
    if not isinstance(impact, dict):
        errors.append(f"{label}.projectile_impact must be an object")
        impact = {}
    if impact.get("accepted") is not True or impact.get("status") != "damage_event":
        errors.append(f"{label}.projectile_impact must be an accepted damage_event receipt")
    if impact.get("server_committed") is not True:
        errors.append(f"{label}.projectile_impact.server_committed must be true")
    if impact.get("projectile_id") != spawn.get("projectile_id"):
        errors.append(f"{label}.projectile_impact.projectile_id must match spawn")
    if impact.get("source_entity_id") != spawn.get("source_entity_id") or impact.get("source_generation") != spawn.get("source_generation"):
        errors.append(f"{label}.projectile_impact source identity must match spawn")
    if not isinstance(impact.get("target_entity_id"), str) or not impact["target_entity_id"].strip() or not _positive_int(impact.get("target_generation")):
        errors.append(f"{label}.projectile_impact target identity must be valid")
    if not _positive_int(impact.get("event_sequence")) or not _non_negative_number(impact.get("damage")) or impact.get("damage", 0) <= 0:
        errors.append(f"{label}.projectile_impact event sequence and damage must be positive")

    commit = report.get("damage_commit")
    if not isinstance(commit, dict):
        errors.append(f"{label}.damage_commit must be an object")
        commit = {}
    if commit.get("accepted") is not True or commit.get("status") != "damage_committed":
        errors.append(f"{label}.damage_commit must be an accepted damage_committed receipt")
    if commit.get("server_committed") is not True or commit.get("projectile_removed") is not True:
        errors.append(f"{label}.damage_commit must remove the resolved projectile server-side")
    if commit.get("projectile_id") != spawn.get("projectile_id"):
        errors.append(f"{label}.damage_commit.projectile_id must match spawn")
    if not _non_negative_number(commit.get("applied_damage")) or not _non_negative_number(commit.get("remaining_health")):
        errors.append(f"{label}.damage_commit health values must be non-negative numbers")
    if _non_negative_number(impact.get("damage")) and _non_negative_number(commit.get("applied_damage")) and commit["applied_damage"] > impact["damage"]:
        errors.append(f"{label}.damage_commit.applied_damage cannot exceed projectile damage")

    boarding = report.get("boarding")
    if not isinstance(boarding, dict):
        errors.append(f"{label}.boarding must be an object")
        boarding = {}
    if boarding.get("accepted") is not True or boarding.get("status") != "boarded":
        errors.append(f"{label}.boarding must be an accepted boarded receipt")
    if boarding.get("server_committed") is not True:
        errors.append(f"{label}.boarding.server_committed must be true")
    for key in ("peer_id", "ship_generation", "frame_generation", "seat_generation", "claim_sequence"):
        if not _positive_int(boarding.get(key)):
            errors.append(f"{label}.boarding.{key} must be positive")
    for key in ("avatar_id", "ship_id", "frame_id", "seat_id", "role"):
        if not isinstance(boarding.get(key), str) or not boarding[key].strip():
            errors.append(f"{label}.boarding.{key} must be non-empty")
    if boarding.get("role") not in {"pilot", "gunner", "passenger", "engineer"}:
        errors.append(f"{label}.boarding.role must be supported")
    if boarding.get("source_peer_id") != boarding.get("authority_peer_id"):
        errors.append(f"{label}.boarding.source_peer_id must be the authority peer")

    required_rejections = {"spoofed_peer", "stale_ship_generation", "stale_frame_generation", "role_mismatch", "stale_sequence", "seat_occupied"}
    rejections = report.get("rejections")
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
    else:
        for index, rejection in enumerate(rejections):
            prefix = f"{label}.rejections[{index}]"
            status = rejection.get("status") if isinstance(rejection, dict) else None
            if status in required_rejections:
                seen.add(status)
            else:
                errors.append(f"{prefix}.status is not a required projectile/boarding rejection")
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
        for status in sorted(required_rejections - seen):
            errors.append(f"{label}.rejections must include {status}")
    return errors


def validate_rollup_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_rollup(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    args = parser.parse_args()
    errors = validate_rollup_file(args.rollup)
    if errors:
        print("NETWORK_PROJECTILE_BOARDING_AUTHORITY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_PROJECTILE_BOARDING_AUTHORITY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
