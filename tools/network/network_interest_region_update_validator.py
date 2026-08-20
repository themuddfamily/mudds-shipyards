#!/usr/bin/env python3
"""Validate detached replication-interest region update evidence.

The ledger checks a server-owned region update and its visible batch against
entity geometry and capacity. Invalid or unauthorized updates must leave the
subscription unchanged; this is fixture evidence only, not a live network
test.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_interest_region_update"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _vector(value: Any) -> tuple[float, float, float] | None:
    if not isinstance(value, list) or len(value) != 3 or any(isinstance(item, bool) or not isinstance(item, (int, float)) for item in value):
        return None
    result = tuple(float(item) for item in value)
    return result if all(math.isfinite(item) for item in result) else None


def _region(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return {}
    center = _vector(value.get("center"))
    if center is None:
        errors.append(f"{label}.center must be finite three-number vector")
    radius = value.get("radius")
    if not isinstance(radius, (int, float)) or isinstance(radius, bool) or not math.isfinite(float(radius)) or radius <= 0:
        errors.append(f"{label}.radius must be positive and finite")
    max_entities = value.get("max_entities")
    if not _positive_int(max_entities) or max_entities > 512:
        errors.append(f"{label}.max_entities must be in 1..512")
    return {**value, "_center": center, "_radius": float(radius) if isinstance(radius, (int, float)) and not isinstance(radius, bool) else None}


def _ids(value: Any, label: str, errors: list[str]) -> set[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        errors.append(f"{label} must be an array of non-empty strings")
        return set()
    if value != sorted(value):
        errors.append(f"{label} must be sorted")
    if len(value) != len(set(value)):
        errors.append(f"{label} must not contain duplicates")
    return set(value)


def validate_update(report: Any, label: str = "update") -> list[str]:
    """Return region geometry, batch, and update-fence errors."""

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
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if not _positive_int(report.get("peer_id")):
        errors.append(f"{label}.peer_id must be positive")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        if audit.get("server_owns_interest") is not True or audit.get("server_owns_replication_budget") is not True:
            errors.append(f"{label}.audit must state server-owned interest and budget")
        if audit.get("client_can_mutate_state") is not False:
            errors.append(f"{label}.audit.client_can_mutate_state must be false")

    before = _region(report.get("region_before"), f"{label}.region_before", errors)
    after = _region(report.get("region_after"), f"{label}.region_after", errors)
    if before and after and before.get("center") == after.get("center") and before.get("radius") == after.get("radius") and before.get("max_entities") == after.get("max_entities"):
        errors.append(f"{label}.region_after must change at least one region field")

    entities = report.get("entities")
    entity_by_id: dict[str, dict[str, Any]] = {}
    if not isinstance(entities, list) or not entities:
        errors.append(f"{label}.entities must be a non-empty array")
        entities = []
    for index, entity in enumerate(entities):
        prefix = f"{label}.entities[{index}]"
        if not isinstance(entity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entity_id = entity.get("entity_id")
        if not isinstance(entity_id, str) or not entity_id.strip() or entity_id in entity_by_id:
            errors.append(f"{prefix}.entity_id must be unique and non-empty")
            continue
        entity_by_id[entity_id] = entity
        position = _vector(entity.get("position"))
        if position is None:
            errors.append(f"{prefix}.position must be finite three-number vector")
        replication_radius = entity.get("replication_radius")
        if not isinstance(replication_radius, (int, float)) or isinstance(replication_radius, bool) or not math.isfinite(float(replication_radius)) or replication_radius <= 0:
            errors.append(f"{prefix}.replication_radius must be positive and finite")
        entity["_position"] = position
    if list(entity_by_id) != sorted(entity_by_id):
        errors.append(f"{label}.entities must be sorted by entity_id")

    before_visible = _ids(report.get("visible_before"), f"{label}.visible_before", errors)
    after_visible = _ids(report.get("visible_after"), f"{label}.visible_after", errors)
    if not before_visible <= set(entity_by_id) or not after_visible <= set(entity_by_id):
        errors.append(f"{label}.visible batches must reference known entities")
    if isinstance(before.get("max_entities"), int) and len(before_visible) > before["max_entities"]:
        errors.append(f"{label}.visible_before exceeds region capacity")
    if isinstance(after.get("max_entities"), int) and len(after_visible) > after["max_entities"]:
        errors.append(f"{label}.visible_after exceeds region capacity")
    center = after.get("_center")
    radius = after.get("_radius")
    if center is not None and radius is not None:
        for entity_id in after_visible:
            entity = entity_by_id[entity_id]
            position = entity.get("_position")
            replication_radius = entity.get("replication_radius")
            if position is not None and isinstance(replication_radius, (int, float)) and math.dist(center, position) > min(radius, float(replication_radius)) + 1e-9:
                errors.append(f"{label}.visible_after entity {entity_id} lies outside updated region")

    receipt = report.get("receipt")
    if not isinstance(receipt, dict):
        errors.append(f"{label}.receipt must be an object")
    else:
        if receipt.get("accepted") is not True or receipt.get("status") != "interest_updated":
            errors.append(f"{label}.receipt must be an accepted interest_updated receipt")
        if receipt.get("source_peer_id") != receipt.get("authority_peer_id") or receipt.get("peer_id") != report.get("peer_id"):
            errors.append(f"{label}.receipt must be an authority receipt for the reported peer")
        if receipt.get("snapshot_detached") is not True:
            errors.append(f"{label}.receipt.snapshot_detached must be true")

    rejections = report.get("rejections")
    required = {"unauthorized_source", "unknown_peer", "invalid_interest_region", "invalid_interest_capacity"}
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
    else:
        for index, rejection in enumerate(rejections):
            prefix = f"{label}.rejections[{index}]"
            status = rejection.get("status") if isinstance(rejection, dict) else None
            if status in required:
                seen.add(status)
            else:
                errors.append(f"{prefix}.status is not a required region rejection")
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
            if isinstance(rejection, dict) and rejection.get("region_changed") is not False:
                errors.append(f"{prefix}.region_changed must be false")
        for status in sorted(required - seen):
            errors.append(f"{label}.rejections must include {status}")
    return errors


def validate_update_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_update(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("update", type=Path)
    args = parser.parse_args()
    errors = validate_update_file(args.update)
    if errors:
        print("NETWORK_INTEREST_REGION_UPDATE_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_INTEREST_REGION_UPDATE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
