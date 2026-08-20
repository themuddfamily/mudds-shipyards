#!/usr/bin/env python3
"""Validate accepted peer-interest generation update evidence.

The ledger records only current-generation server commits. It checks that
subscription generations and update sequences advance together, each region
stays bounded, and receipts remain detached from client mutation. No live peer
or transport is used.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_interest_generation_update_ledger"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_updates(report: Any, label: str = "ledger") -> list[str]:
    """Return accepted current-generation update errors."""

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

    peer = report.get("peer")
    if not isinstance(peer, dict):
        errors.append(f"{label}.peer must be an object")
        peer = {}
    if not _positive_int(peer.get("peer_id")) or not _positive_int(peer.get("peer_generation")):
        errors.append(f"{label}.peer.peer_id and peer_generation must be positive")
    start_subscription = peer.get("subscription_generation")
    start_sequence = peer.get("update_sequence")
    if not _positive_int(start_subscription) or not _positive_int(start_sequence):
        errors.append(f"{label}.peer subscription_generation and update_sequence must be positive")
    if not isinstance(peer.get("region_digest"), str) or not peer["region_digest"].strip():
        errors.append(f"{label}.peer.region_digest must be non-empty")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in ("server_owns_interest", "server_owns_peer_generation"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        if audit.get("client_can_mutate_interest") is not False:
            errors.append(f"{label}.audit.client_can_mutate_interest must be false")

    updates = report.get("updates")
    if not isinstance(updates, list) or not updates:
        errors.append(f"{label}.updates must be a non-empty array")
        updates = []
    previous_subscription = start_subscription if _positive_int(start_subscription) else 0
    previous_sequence = start_sequence if _positive_int(start_sequence) else 0
    previous_digest = peer.get("region_digest")
    for index, update in enumerate(updates):
        prefix = f"{label}.updates[{index}]"
        if not isinstance(update, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if update.get("accepted") is not True or update.get("status") != "interest_updated":
            errors.append(f"{prefix} must be accepted interest_updated")
        if update.get("source_peer_id") != update.get("authority_peer_id") or update.get("peer_id") != peer.get("peer_id"):
            errors.append(f"{prefix} must be server-invoked for the current peer")
        if update.get("peer_generation") != peer.get("peer_generation"):
            errors.append(f"{prefix}.peer_generation must match current peer generation")
        subscription = update.get("subscription_generation")
        sequence = update.get("update_sequence")
        if not _positive_int(subscription) or subscription <= previous_subscription:
            errors.append(f"{prefix}.subscription_generation must advance")
        if not _positive_int(sequence) or sequence <= previous_sequence:
            errors.append(f"{prefix}.update_sequence must advance")
        digest = update.get("region_digest")
        if not isinstance(digest, str) or not digest.strip() or digest == previous_digest:
            errors.append(f"{prefix}.region_digest must change")
        max_entities = update.get("max_entities")
        visible_count = update.get("visible_entity_count")
        if not _positive_int(max_entities) or max_entities > 512:
            errors.append(f"{prefix}.max_entities must be in 1..512")
        if not isinstance(visible_count, int) or isinstance(visible_count, bool) or visible_count < 0:
            errors.append(f"{prefix}.visible_entity_count must be non-negative")
        elif _positive_int(max_entities) and visible_count > max_entities:
            errors.append(f"{prefix}.visible_entity_count exceeds max_entities")
        if update.get("snapshot_detached") is not True:
            errors.append(f"{prefix}.snapshot_detached must be true")
        if _positive_int(subscription):
            previous_subscription = subscription
        if _positive_int(sequence):
            previous_sequence = sequence
        if isinstance(digest, str) and digest.strip():
            previous_digest = digest

    final = report.get("final")
    if not isinstance(final, dict):
        errors.append(f"{label}.final must be an object")
    else:
        if final.get("subscription_generation") != previous_subscription or final.get("update_sequence") != previous_sequence or final.get("region_digest") != previous_digest:
            errors.append(f"{label}.final must match the last accepted update")
        if final.get("active") is not True:
            errors.append(f"{label}.final.active must be true")
    return errors


def validate_updates_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_updates(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args()
    errors = validate_updates_file(args.ledger)
    if errors:
        print("NETWORK_INTEREST_GENERATION_UPDATE_LEDGER_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_INTEREST_GENERATION_UPDATE_LEDGER_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
