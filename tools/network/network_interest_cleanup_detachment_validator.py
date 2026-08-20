#!/usr/bin/env python3
"""Validate detached replication-interest cleanup and entity detachment.

The report checks that disconnect cleanup removes only the peer's interest
subscription, preserves registered entity generations, and clears ownership
for entities formerly owned by that peer. It is a fixture gate and never runs
a live network or mutates the runtime interest authority.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_interest_cleanup_detachment"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _id_set(value: Any, label: str, errors: list[str]) -> set[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        errors.append(f"{label} must be an array of non-empty strings")
        return set()
    if len(value) != len(set(value)):
        errors.append(f"{label} must not contain duplicates")
    return set(value)


def validate_cleanup(report: Any, label: str = "cleanup") -> list[str]:
    """Return interest subscription and ownership-detachment errors."""

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
        for key in ("server_owns_interest", "server_owns_entity_generations", "server_owns_ownership_transfers"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        for key in ("client_can_mutate_state", "client_can_transfer_ownership"):
            if audit.get(key) is not False:
                errors.append(f"{label}.audit.{key} must be false")

    before = report.get("before")
    if not isinstance(before, dict):
        errors.append(f"{label}.before must be an object")
        before = {}
    if before.get("peer_interest_present") is not True:
        errors.append(f"{label}.before.peer_interest_present must be true")
    before_entities = _id_set(before.get("entity_ids"), f"{label}.before.entity_ids", errors)
    owned_before = _id_set(before.get("peer_owned_entity_ids"), f"{label}.before.peer_owned_entity_ids", errors)
    if not owned_before <= before_entities:
        errors.append(f"{label}.before.peer_owned_entity_ids must be registered entities")

    cleanup = report.get("cleanup_receipt")
    if not isinstance(cleanup, dict):
        errors.append(f"{label}.cleanup_receipt must be an object")
        cleanup = {}
    if cleanup.get("accepted") is not True or cleanup.get("status") not in {"peer_disconnected", "interest_removed"}:
        errors.append(f"{label}.cleanup_receipt must be an accepted interest cleanup receipt")
    if cleanup.get("source_peer_id") != cleanup.get("authority_peer_id"):
        errors.append(f"{label}.cleanup_receipt must be server-invoked")
    if cleanup.get("peer_id") != report.get("peer_id"):
        errors.append(f"{label}.cleanup_receipt.peer_id must match report peer")
    for key in ("interest_removed", "peer_removed", "ownership_detached"):
        if cleanup.get(key) is not True:
            errors.append(f"{label}.cleanup_receipt.{key} must be true")
    retained = _id_set(cleanup.get("retained_entity_ids"), f"{label}.cleanup_receipt.retained_entity_ids", errors)
    if retained != before_entities:
        errors.append(f"{label}.cleanup_receipt.retained_entity_ids must preserve all entities")

    after = report.get("after")
    if not isinstance(after, dict):
        errors.append(f"{label}.after must be an object")
        after = {}
    if after.get("peer_interest_present") is not False:
        errors.append(f"{label}.after.peer_interest_present must be false")
    after_entities = _id_set(after.get("entity_ids"), f"{label}.after.entity_ids", errors)
    if after_entities != before_entities:
        errors.append(f"{label}.after.entity_ids must preserve the registered entity set")
    unowned_after = _id_set(after.get("unowned_entity_ids"), f"{label}.after.unowned_entity_ids", errors)
    if unowned_after != owned_before:
        errors.append(f"{label}.after.unowned_entity_ids must equal the disconnected peer's owned entities")
    if after.get("entity_generations_preserved") is not True:
        errors.append(f"{label}.after.entity_generations_preserved must be true")
    if after.get("snapshot_detached") is not True:
        errors.append(f"{label}.after.snapshot_detached must be true")

    stale = report.get("stale_update")
    if not isinstance(stale, dict):
        errors.append(f"{label}.stale_update must be an object")
    else:
        if stale.get("accepted") is not False or stale.get("status") not in {"unknown_peer", "unauthorized_source", "stale_peer_generation"}:
            errors.append(f"{label}.stale_update must be a rejected stale/unknown peer update")
        if stale.get("server_rejected") is not True or stale.get("recreated_interest") is not False:
            errors.append(f"{label}.stale_update must not recreate interest")
    return errors


def validate_cleanup_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_cleanup(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cleanup", type=Path)
    args = parser.parse_args()
    errors = validate_cleanup_file(args.cleanup)
    if errors:
        print("NETWORK_INTEREST_CLEANUP_DETACHMENT_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_INTEREST_CLEANUP_DETACHMENT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
