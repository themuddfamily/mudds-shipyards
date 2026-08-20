#!/usr/bin/env python3
"""Validate detached network damage/recovery/respawn authority evidence.

The rollup joins server damage and component receipts to recovery, opaque
respawn reservation, and generation-advancing commit receipts. It checks
authority boundaries and fail-closed rejection coverage without simulating
combat, health, physics, or a live network.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_damage_respawn_authority"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_damage_respawn_integration_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _positive_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value)) and value > 0


def validate_rollup(report: Any, label: str = "rollup") -> list[str]:
    """Return structural and lifecycle-boundary errors for one rollup."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network", "simulates_health_or_physics"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in (
            "server_owns_damage_event_order",
            "server_owns_component_generation",
            "server_owns_recovery_gate",
            "server_owns_respawn_generation",
        ):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        for key in ("client_can_mutate_health", "client_can_mutate_recovery", "client_can_mutate_respawn", "owns_health_store", "owns_spawn_instantiation"):
            if audit.get(key) is not False:
                errors.append(f"{label}.audit.{key} must be false")

    entity = report.get("entity")
    if not isinstance(entity, dict):
        errors.append(f"{label}.entity must be an object")
        entity = {}
    if not isinstance(entity.get("entity_id"), str) or not entity.get("entity_id").strip():
        errors.append(f"{label}.entity.entity_id must be non-empty")
    if not _positive_int(entity.get("owner_peer_id")):
        errors.append(f"{label}.entity.owner_peer_id must be positive")
    for key in ("entity_generation", "component_generation"):
        if not _positive_int(entity.get(key)):
            errors.append(f"{label}.entity.{key} must be positive")
    for key in ("recovery_seconds", "invulnerability_seconds"):
        if not _positive_number(entity.get(key)):
            errors.append(f"{label}.entity.{key} must be positive")

    damage = report.get("damage")
    if not isinstance(damage, dict):
        errors.append(f"{label}.damage must be an object")
        damage = {}
    if damage.get("accepted") is not True or damage.get("status") != "damage_destroyed":
        errors.append(f"{label}.damage must be an accepted damage_destroyed receipt")
    if damage.get("server_committed") is not True or damage.get("state_after") != "recovering":
        errors.append(f"{label}.damage must be server-committed and enter recovering")
    event = damage.get("event")
    if not isinstance(event, dict):
        errors.append(f"{label}.damage.event must be an object")
        event = {}
    if event.get("target_entity_id") != entity.get("entity_id") or event.get("target_generation") != entity.get("entity_generation"):
        errors.append(f"{label}.damage.event target identity must match entity")
    if not _positive_int(event.get("event_sequence")) or not _positive_number(event.get("damage")):
        errors.append(f"{label}.damage.event sequence and damage must be positive")
    component = damage.get("component_receipt")
    if not isinstance(component, dict) or component.get("accepted") is not True or component.get("reason") != "applied":
        errors.append(f"{label}.damage.component_receipt must be an applied receipt")
    elif component.get("generation") != entity.get("component_generation") or not _positive_int(component.get("sequence")):
        errors.append(f"{label}.damage.component_receipt generation/sequence must match entity")

    recovery = report.get("recovery")
    if not isinstance(recovery, dict):
        errors.append(f"{label}.recovery must be an object")
    else:
        if recovery.get("accepted") is not True or recovery.get("status") != "recovery_ready":
            errors.append(f"{label}.recovery must be an accepted recovery_ready receipt")
        if recovery.get("state_before") != "recovering" or recovery.get("state_after") != "recovery_ready":
            errors.append(f"{label}.recovery must advance recovering to recovery_ready")
        if not _positive_number(recovery.get("elapsed_seconds")) or recovery.get("elapsed_seconds", 0) < entity.get("recovery_seconds", 0):
            errors.append(f"{label}.recovery.elapsed_seconds must meet recovery_seconds")

    reservation = report.get("reservation")
    if not isinstance(reservation, dict):
        errors.append(f"{label}.reservation must be an object")
    else:
        if reservation.get("accepted") is not True or reservation.get("status") != "respawn_reserved":
            errors.append(f"{label}.reservation must be an accepted respawn_reserved receipt")
        for key in ("target_id", "respawn_token"):
            if not isinstance(reservation.get(key), str) or not reservation[key].strip():
                errors.append(f"{label}.reservation.{key} must be non-empty")
        if reservation.get("state_after") != "respawn_pending" or reservation.get("server_committed") is not True:
            errors.append(f"{label}.reservation must enter server-committed respawn_pending")

    commit = report.get("commit")
    if not isinstance(commit, dict):
        errors.append(f"{label}.commit must be an object")
    else:
        if commit.get("accepted") is not True or commit.get("status") != "respawn_committed":
            errors.append(f"{label}.commit must be an accepted respawn_committed receipt")
        if commit.get("state_after") != "active" or commit.get("server_committed") is not True:
            errors.append(f"{label}.commit must return an active server-committed entity")
        if commit.get("entity_generation") != entity.get("entity_generation", 0) + 1:
            errors.append(f"{label}.commit.entity_generation must advance exactly once")
        if commit.get("component_generation") != entity.get("component_generation", 0) + 1:
            errors.append(f"{label}.commit.component_generation must advance exactly once")
        if commit.get("target_id") != (reservation or {}).get("target_id") or commit.get("respawn_token") != (reservation or {}).get("respawn_token"):
            errors.append(f"{label}.commit target and token must match reservation")
        reset = commit.get("component_reset")
        if not isinstance(reset, dict) or reset.get("accepted") is not True or reset.get("reason") != "reset" or reset.get("generation") != entity.get("component_generation", 0) + 1:
            errors.append(f"{label}.commit.component_reset must advance with reset reason")

    required_rejections = {"unauthorized_source", "stale_damage_event", "stale_entity_generation", "recovery_not_ready", "respawn_identity_mismatch"}
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
                errors.append(f"{prefix}.status is not a required damage/respawn rejection")
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
        print("NETWORK_DAMAGE_RESPAWN_AUTHORITY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_DAMAGE_RESPAWN_AUTHORITY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
