#!/usr/bin/env python3
"""Validate detached visible/deferred replication-interest partitions.

The ledger proves that every candidate entity is classified exactly once as
visible, deferred, or out-of-interest, with deterministic IDs and a bounded
visible batch. It is a fixture validator, not a live replication test.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_visible_deferred_partition"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"


def _ids(value: Any, label: str, errors: list[str]) -> set[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        errors.append(f"{label} must be an array of non-empty strings")
        return set()
    if value != sorted(value):
        errors.append(f"{label} must be sorted")
    if len(value) != len(set(value)):
        errors.append(f"{label} must not contain duplicates")
    return set(value)


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_partition(report: Any, label: str = "partition") -> list[str]:
    """Return partition coverage, ordering, and capacity errors."""

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

    candidates = _ids(report.get("candidate_entity_ids"), f"{label}.candidate_entity_ids", errors)
    visible = _ids(report.get("visible_entity_ids"), f"{label}.visible_entity_ids", errors)
    deferred = _ids(report.get("deferred_entity_ids"), f"{label}.deferred_entity_ids", errors)
    excluded = _ids(report.get("excluded_entity_ids"), f"{label}.excluded_entity_ids", errors)
    if visible & deferred or visible & excluded or deferred & excluded:
        errors.append(f"{label} partition sets must be disjoint")
    if visible | deferred | excluded != candidates:
        errors.append(f"{label} partition sets must cover every candidate exactly once")

    max_entities = report.get("max_entities_per_tick")
    if not _positive_int(max_entities) or max_entities > 512:
        errors.append(f"{label}.max_entities_per_tick must be in 1..512")
    elif len(visible) > max_entities:
        errors.append(f"{label}.visible_entity_ids exceeds max_entities_per_tick")
    max_deferred = report.get("max_deferred_entities")
    if not _positive_int(max_deferred) or max_deferred > 512:
        errors.append(f"{label}.max_deferred_entities must be in 1..512")
    elif len(deferred) > max_deferred:
        errors.append(f"{label}.deferred_entity_ids exceeds max_deferred_entities")

    entities = report.get("entities")
    entity_by_id: dict[str, dict[str, Any]] = {}
    if not isinstance(entities, list):
        errors.append(f"{label}.entities must be an array")
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
        if not isinstance(entity.get("in_interest"), bool):
            errors.append(f"{prefix}.in_interest must be boolean")
    if list(entity_by_id) != sorted(entity_by_id):
        errors.append(f"{label}.entities must be sorted by entity_id")
    if set(entity_by_id) != candidates:
        errors.append(f"{label}.entities must match candidate_entity_ids")
    for entity_id, entity in entity_by_id.items():
        in_interest = entity.get("in_interest") is True
        if entity_id in excluded and in_interest:
            errors.append(f"{label} excluded entity {entity_id} cannot be in interest")
        if entity_id in visible | deferred and not in_interest:
            errors.append(f"{label} visible/deferred entity {entity_id} must be in interest")

    receipt = report.get("batch_receipt")
    if not isinstance(receipt, dict):
        errors.append(f"{label}.batch_receipt must be an object")
    else:
        if receipt.get("accepted") is not True or receipt.get("status") not in {"replicated", "rate_limited"}:
            errors.append(f"{label}.batch_receipt must be accepted replicated or rate_limited")
        if receipt.get("source_peer_id") != receipt.get("authority_peer_id") or receipt.get("peer_id") != report.get("peer_id"):
            errors.append(f"{label}.batch_receipt must be server-owned for the peer")
        if receipt.get("visible_count") != len(visible) or receipt.get("deferred_count") != len(deferred):
            errors.append(f"{label}.batch_receipt counts must match the partition")
        if receipt.get("snapshot_detached") is not True:
            errors.append(f"{label}.batch_receipt.snapshot_detached must be true")
    return errors


def validate_partition_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_partition(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("partition", type=Path)
    args = parser.parse_args()
    errors = validate_partition_file(args.partition)
    if errors:
        print("NETWORK_VISIBLE_DEFERRED_PARTITION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_VISIBLE_DEFERRED_PARTITION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
