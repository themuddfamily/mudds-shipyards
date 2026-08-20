#!/usr/bin/env python3
"""Validate detached cleanup evidence around a session migration rotation.

The report proves that rotation detaches every old transport, retains only
generation-bearing attachments for pending rebind, and leaves no orphan
active peers. It is a fixture gate over the migration ledger, not a live
session or transport test.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_session_migration_cleanup"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_session_migration_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _id_set(value: Any, label: str, errors: list[str]) -> set[int]:
    if not isinstance(value, list) or any(not _positive_int(item) for item in value):
        errors.append(f"{label} must be an array of positive peer IDs")
        return set()
    if len(value) != len(set(value)):
        errors.append(f"{label} must not contain duplicates")
    return set(value)


def validate_cleanup(report: Any, label: str = "cleanup") -> list[str]:
    """Return migration-rotation cleanup and orphan-state errors."""

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
    for key in ("native_claims", "uses_live_sessions"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in ("server_owns_rotation", "server_owns_attachment_rebind", "stale_packets_rejected"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        if audit.get("client_can_mutate_attachment") is not False:
            errors.append(f"{label}.audit.client_can_mutate_attachment must be false")

    before = report.get("pre_rotation_peer_ids")
    before_set = _id_set(before, f"{label}.pre_rotation_peer_ids", errors)
    rotation = report.get("rotation")
    if not isinstance(rotation, dict):
        errors.append(f"{label}.rotation must be an object")
        rotation = {}
    if rotation.get("accepted") is not True or rotation.get("status") != "server_rotated":
        errors.append(f"{label}.rotation must be an accepted server_rotated receipt")
    if rotation.get("server_authority") is not True:
        errors.append(f"{label}.rotation.server_authority must be true")
    released_set = _id_set(rotation.get("released_peer_ids"), f"{label}.rotation.released_peer_ids", errors)
    if before_set != released_set:
        errors.append(f"{label}.rotation.released_peer_ids must exactly match pre_rotation_peer_ids")

    post = report.get("post_rotation")
    if not isinstance(post, dict):
        errors.append(f"{label}.post_rotation must be an object")
        post = {}
    active_set = _id_set(post.get("active_peer_ids"), f"{label}.post_rotation.active_peer_ids", errors)
    pending_set = _id_set(post.get("pending_rebind_peer_ids"), f"{label}.post_rotation.pending_rebind_peer_ids", errors)
    if active_set:
        errors.append(f"{label}.post_rotation.active_peer_ids must be empty after rotation")
    if pending_set != before_set:
        errors.append(f"{label}.post_rotation.pending_rebind_peer_ids must retain every released peer")
    if post.get("attachments_retained") is not True:
        errors.append(f"{label}.post_rotation.attachments_retained must be true")
    if post.get("old_transports_detached") is not True:
        errors.append(f"{label}.post_rotation.old_transports_detached must be true")

    rebind = report.get("rebind")
    if not isinstance(rebind, dict):
        errors.append(f"{label}.rebind must be an object")
        rebind = {}
    rebind_peer = rebind.get("peer_id")
    if not _positive_int(rebind_peer) or rebind_peer not in pending_set:
        errors.append(f"{label}.rebind.peer_id must identify a pending peer")
    if rebind.get("accepted") is not True or rebind.get("status") != "peer_rebound":
        errors.append(f"{label}.rebind must be an accepted peer_rebound receipt")
    if rebind.get("attachments_restored") is not True or rebind.get("server_authority") is not True:
        errors.append(f"{label}.rebind must restore attachments under server authority")
    if not _positive_int(rebind.get("peer_generation_before")) or not _positive_int(rebind.get("peer_generation_after")) or rebind.get("peer_generation_after", 0) <= rebind.get("peer_generation_before", 0):
        errors.append(f"{label}.rebind peer generation must advance")

    post_rebind = report.get("post_rebind")
    if not isinstance(post_rebind, dict):
        errors.append(f"{label}.post_rebind must be an object")
        post_rebind = {}
    active_after = _id_set(post_rebind.get("active_peer_ids"), f"{label}.post_rebind.active_peer_ids", errors)
    expected_active = {rebind_peer} if _positive_int(rebind_peer) else set()
    if active_after != expected_active:
        errors.append(f"{label}.post_rebind.active_peer_ids must contain only the rebound peer")
    pending_after = _id_set(post_rebind.get("pending_rebind_peer_ids"), f"{label}.post_rebind.pending_rebind_peer_ids", errors)
    if pending_after != pending_set - expected_active:
        errors.append(f"{label}.post_rebind.pending_rebind_peer_ids must remove the rebound peer")
    if post_rebind.get("no_orphan_active_peers") is not True:
        errors.append(f"{label}.post_rebind.no_orphan_active_peers must be true")

    stale = report.get("stale_packet_cleanup")
    if not isinstance(stale, dict):
        errors.append(f"{label}.stale_packet_cleanup must be an object")
    else:
        if stale.get("accepted") is not False or stale.get("status") not in {"stale_peer_generation", "stale_session_generation", "stale_migration_generation"}:
            errors.append(f"{label}.stale_packet_cleanup must be a rejected stale-generation receipt")
        if stale.get("server_rejected") is not True:
            errors.append(f"{label}.stale_packet_cleanup.server_rejected must be true")
        if stale.get("altered_attachment") is not False:
            errors.append(f"{label}.stale_packet_cleanup.altered_attachment must be false")
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
        print("NETWORK_SESSION_MIGRATION_CLEANUP_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SESSION_MIGRATION_CLEANUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
