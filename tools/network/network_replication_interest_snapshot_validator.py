#!/usr/bin/env python3
"""Validate a detached server replication-interest snapshot.

The snapshot records candidate entities, the bounded visible/deferred split,
and the server-only audit flags exposed by the existing interest authority.
It checks the same distance and stable-ID rules used by the ledger, but never
opens a peer or treats this fixture as transport/native performance evidence.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_replication_interest_snapshot"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
MAX_ENTITIES = 512


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _vector(value: Any) -> tuple[float, float, float] | None:
    if not isinstance(value, list) or len(value) != 3:
        return None
    if any(isinstance(item, bool) or not isinstance(item, (int, float)) for item in value):
        return None
    result = tuple(float(item) for item in value)
    return result if all(math.isfinite(item) for item in result) else None


def _distance_sq(left: tuple[float, float, float], right: tuple[float, float, float]) -> float:
    return sum((a - b) ** 2 for a, b in zip(left, right))


def validate_snapshot(report: Any, label: str = "snapshot") -> list[str]:
    """Return structural and interest-boundary errors for one snapshot."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if report.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if report.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    if report.get("native_claims") is not False:
        errors.append(f"{label}.native_claims must be false")
    if report.get("uses_live_network") is not False:
        errors.append(f"{label}.uses_live_network must be false")
    if report.get("policy_version") != POLICY_VERSION:
        errors.append(f"{label}.policy_version must be {POLICY_VERSION}")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in ("server_owns_interest", "server_owns_replication_budget", "server_owns_entity_generations", "server_owns_ownership_transfers"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        for key in ("client_can_mutate_state", "client_can_transfer_ownership"):
            if audit.get(key) is not False:
                errors.append(f"{label}.audit.{key} must be false")

    peer = report.get("peer")
    center: tuple[float, float, float] | None = None
    radius: float | None = None
    max_entities: int | None = None
    if not isinstance(peer, dict):
        errors.append(f"{label}.peer must be an object")
    else:
        if not _positive_int(peer.get("peer_id")):
            errors.append(f"{label}.peer.peer_id must be positive")
        center = _vector(peer.get("center"))
        if center is None:
            errors.append(f"{label}.peer.center must be a finite three-number vector")
        raw_radius = peer.get("radius")
        if not isinstance(raw_radius, (int, float)) or isinstance(raw_radius, bool) or not math.isfinite(float(raw_radius)) or raw_radius <= 0:
            errors.append(f"{label}.peer.radius must be positive and finite")
        else:
            radius = float(raw_radius)
        if not _positive_int(peer.get("max_entities")) or peer["max_entities"] > MAX_ENTITIES:
            errors.append(f"{label}.peer.max_entities must be in 1..{MAX_ENTITIES}")
        else:
            max_entities = peer["max_entities"]

    candidates = report.get("candidates")
    candidate_by_id: dict[str, dict[str, Any]] = {}
    in_region_by_id: dict[str, bool] = {}
    if not isinstance(candidates, list) or not candidates:
        errors.append(f"{label}.candidates must be a non-empty array")
        candidates = []
    for index, candidate in enumerate(candidates):
        prefix = f"{label}.candidates[{index}]"
        if not isinstance(candidate, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entity_id = candidate.get("entity_id")
        if not isinstance(entity_id, str) or not entity_id.strip() or entity_id in candidate_by_id:
            errors.append(f"{prefix}.entity_id must be a unique non-empty string")
            continue
        candidate_by_id[entity_id] = candidate
        position = _vector(candidate.get("position"))
        if position is None:
            errors.append(f"{prefix}.position must be a finite three-number vector")
        if not _non_negative_int(candidate.get("owner_peer_id")):
            errors.append(f"{prefix}.owner_peer_id must be non-negative")
        if not _positive_int(candidate.get("entity_generation")):
            errors.append(f"{prefix}.entity_generation must be positive")
        if not _positive_int(candidate.get("state_revision")):
            errors.append(f"{prefix}.state_revision must be positive")
        raw_replication_radius = candidate.get("replication_radius")
        if not isinstance(raw_replication_radius, (int, float)) or isinstance(raw_replication_radius, bool) or not math.isfinite(float(raw_replication_radius)) or raw_replication_radius <= 0:
            errors.append(f"{prefix}.replication_radius must be positive and finite")
        if center is not None and radius is not None and position is not None and isinstance(raw_replication_radius, (int, float)) and raw_replication_radius > 0:
            in_region_by_id[entity_id] = _distance_sq(center, position) <= min(radius, float(raw_replication_radius)) ** 2

    candidate_ids = list(candidate_by_id)
    if candidate_ids != sorted(candidate_ids):
        errors.append(f"{label}.candidates must be sorted by entity_id")

    visible = report.get("visible_entity_ids")
    deferred = report.get("deferred_entity_ids")
    excluded = report.get("excluded_entity_ids")
    sets: dict[str, set[str]] = {}
    for name, values in (("visible_entity_ids", visible), ("deferred_entity_ids", deferred), ("excluded_entity_ids", excluded)):
        if not isinstance(values, list) or any(not isinstance(item, str) for item in values):
            errors.append(f"{label}.{name} must be an array of strings")
            sets[name] = set()
            continue
        if values != sorted(values):
            errors.append(f"{label}.{name} must be sorted")
        if len(values) != len(set(values)):
            errors.append(f"{label}.{name} must not contain duplicates")
        sets[name] = set(values)
        unknown = sets[name] - set(candidate_by_id)
        if unknown:
            errors.append(f"{label}.{name} contains unknown entity IDs")

    visible_set = sets.get("visible_entity_ids", set())
    deferred_set = sets.get("deferred_entity_ids", set())
    excluded_set = sets.get("excluded_entity_ids", set())
    if visible_set & deferred_set or visible_set & excluded_set or deferred_set & excluded_set:
        errors.append(f"{label} visible, deferred, and excluded entity sets must be disjoint")
    if max_entities is not None and len(visible_set) > max_entities:
        errors.append(f"{label}.visible_entity_ids exceeds peer.max_entities")
    for entity_id, candidate in candidate_by_id.items():
        in_region = in_region_by_id.get(entity_id, False)
        assigned = entity_id in visible_set or entity_id in deferred_set
        if in_region and not assigned:
            errors.append(f"{label} in-interest entity {entity_id} is missing from visible/deferred output")
        if not in_region and entity_id not in excluded_set:
            errors.append(f"{label} out-of-interest entity {entity_id} must be excluded")
    return errors


def validate_snapshot_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_snapshot(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    args = parser.parse_args()
    errors = validate_snapshot_file(args.snapshot)
    if errors:
        print("NETWORK_REPLICATION_INTEREST_SNAPSHOT_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_REPLICATION_INTEREST_SNAPSHOT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
