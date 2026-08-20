#!/usr/bin/env python3
"""Validate detached accepted-interest snapshot evidence.

The ledger checks the post-update entity snapshot produced for a current peer:
visible entries carry positive revisions and stable IDs, deferred work is
bounded, and unchanged entries are not falsely rewritten. It is not a live
replication or transport test.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_interest_snapshot_update_ledger"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _ids(value: Any, label: str, errors: list[str]) -> set[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        errors.append(f"{label} must be an array of non-empty strings")
        return set()
    if value != sorted(value):
        errors.append(f"{label} must be sorted")
    if len(value) != len(set(value)):
        errors.append(f"{label} must not contain duplicates")
    return set(value)


def validate_snapshot(report: Any, label: str = "snapshot") -> list[str]:
    """Return accepted snapshot update and revision errors."""

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

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        if audit.get("server_owns_interest") is not True or audit.get("server_owns_entity_generations") is not True:
            errors.append(f"{label}.audit must state server-owned interest and entity generations")
        if audit.get("client_can_mutate_state") is not False:
            errors.append(f"{label}.audit.client_can_mutate_state must be false")

    before = report.get("before")
    if not isinstance(before, dict):
        errors.append(f"{label}.before must be an object")
        before = {}
    after = report.get("after")
    if not isinstance(after, dict):
        errors.append(f"{label}.after must be an object")
        after = {}
    for name, snapshot in (("before", before), ("after", after)):
        if not isinstance(snapshot.get("peer_id"), int) or snapshot.get("peer_id") <= 0:
            errors.append(f"{label}.{name}.peer_id must be positive")
        for key in ("peer_generation", "subscription_generation"):
            if not _positive_int(snapshot.get(key)):
                errors.append(f"{label}.{name}.{key} must be positive")
        if not isinstance(snapshot.get("region_digest"), str) or not snapshot["region_digest"].strip():
            errors.append(f"{label}.{name}.region_digest must be non-empty")
    if before.get("peer_id") != after.get("peer_id") or before.get("peer_generation") != after.get("peer_generation"):
        errors.append(f"{label}.after must retain peer identity and generation")
    if _positive_int(before.get("subscription_generation")) and _positive_int(after.get("subscription_generation")) and after["subscription_generation"] <= before["subscription_generation"]:
        errors.append(f"{label}.after.subscription_generation must advance")
    if before.get("region_digest") == after.get("region_digest"):
        errors.append(f"{label}.after.region_digest must change")

    known = _ids(after.get("entity_ids"), f"{label}.after.entity_ids", errors)
    visible = _ids(after.get("visible_entity_ids"), f"{label}.after.visible_entity_ids", errors)
    deferred = _ids(after.get("deferred_entity_ids"), f"{label}.after.deferred_entity_ids", errors)
    unchanged = _ids(after.get("unchanged_entity_ids"), f"{label}.after.unchanged_entity_ids", errors)
    if not visible <= known or not deferred <= known or not unchanged <= known:
        errors.append(f"{label}.after snapshot sets must reference known entities")
    if visible & deferred or visible & unchanged or deferred & unchanged:
        errors.append(f"{label}.after visible/deferred/unchanged sets must be disjoint")
    max_entities = after.get("max_entities")
    if not _positive_int(max_entities) or max_entities > 512:
        errors.append(f"{label}.after.max_entities must be in 1..512")
    elif len(visible) > max_entities:
        errors.append(f"{label}.after.visible_entity_ids exceeds max_entities")

    entries = after.get("visible_entries")
    entry_ids: set[str] = set()
    if not isinstance(entries, list):
        errors.append(f"{label}.after.visible_entries must be an array")
        entries = []
    for index, entry in enumerate(entries):
        prefix = f"{label}.after.visible_entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entity_id = entry.get("entity_id")
        if not isinstance(entity_id, str) or not entity_id.strip() or entity_id in entry_ids:
            errors.append(f"{prefix}.entity_id must be unique and non-empty")
        else:
            entry_ids.add(entity_id)
        if not _positive_int(entry.get("state_revision")) or not _positive_int(entry.get("entity_generation")):
            errors.append(f"{prefix} revisions and generation must be positive")
        if not isinstance(entry.get("owner_peer_id"), int) or isinstance(entry.get("owner_peer_id"), bool) or entry["owner_peer_id"] < 0:
            errors.append(f"{prefix}.owner_peer_id must be non-negative")
        if entry.get("detached") is not True:
            errors.append(f"{prefix}.detached must be true")
    if list(entry_ids) != sorted(list(entry_ids)):
        errors.append(f"{label}.after.visible_entries must be sorted by entity_id")
    if entry_ids != visible:
        errors.append(f"{label}.after.visible_entries must exactly match visible_entity_ids")

    update = report.get("update_receipt")
    if not isinstance(update, dict):
        errors.append(f"{label}.update_receipt must be an object")
    else:
        if update.get("accepted") is not True or update.get("status") != "interest_updated":
            errors.append(f"{label}.update_receipt must be accepted interest_updated")
        if update.get("peer_id") != after.get("peer_id") or update.get("peer_generation") != after.get("peer_generation") or update.get("subscription_generation") != after.get("subscription_generation"):
            errors.append(f"{label}.update_receipt must match after snapshot generations")
        if update.get("source_peer_id") != update.get("authority_peer_id") or update.get("snapshot_detached") is not True:
            errors.append(f"{label}.update_receipt must be server-owned and detached")
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
        print("NETWORK_INTEREST_SNAPSHOT_UPDATE_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_INTEREST_SNAPSHOT_UPDATE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
