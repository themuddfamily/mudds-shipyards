#!/usr/bin/env python3
"""Validate detached peer-interest generation evidence.

The report joins peer lifecycle generations to bounded replication-interest
subscriptions. A current server update may replace a region only for the
current peer generation; stale or unauthorized updates fail closed. No live
peer or transport is involved.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_peer_interest_generation"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _vector(value: Any) -> bool:
    return isinstance(value, list) and len(value) == 3 and all(isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(float(item)) for item in value)


def _region(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return {}
    if not _vector(value.get("center")):
        errors.append(f"{label}.center must be a finite vector")
    radius = value.get("radius")
    if not isinstance(radius, (int, float)) or isinstance(radius, bool) or not math.isfinite(float(radius)) or radius <= 0:
        errors.append(f"{label}.radius must be positive and finite")
    max_entities = value.get("max_entities")
    if not _positive_int(max_entities) or max_entities > 512:
        errors.append(f"{label}.max_entities must be in 1..512")
    return value


def validate_generation(report: Any, label: str = "interest") -> list[str]:
    """Return peer generation and subscription-boundary errors."""

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
        for key in ("server_owns_interest", "server_owns_entity_generations"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        for key in ("client_can_mutate_state", "client_can_mutate_interest"):
            if audit.get(key) is not False:
                errors.append(f"{label}.audit.{key} must be false")

    peer = report.get("peer")
    if not isinstance(peer, dict):
        errors.append(f"{label}.peer must be an object")
        peer = {}
    if not _positive_int(peer.get("peer_id")):
        errors.append(f"{label}.peer.peer_id must be positive")
    for key in ("peer_generation_before", "peer_generation_after", "subscription_generation_before", "subscription_generation_after"):
        if not _positive_int(peer.get(key)):
            errors.append(f"{label}.peer.{key} must be positive")
    if _positive_int(peer.get("peer_generation_before")) and _positive_int(peer.get("peer_generation_after")) and peer["peer_generation_after"] <= peer["peer_generation_before"]:
        errors.append(f"{label}.peer.peer_generation_after must advance")
    if _positive_int(peer.get("subscription_generation_before")) and _positive_int(peer.get("subscription_generation_after")) and peer["subscription_generation_after"] <= peer["subscription_generation_before"]:
        errors.append(f"{label}.peer.subscription_generation_after must advance")

    before = _region(report.get("region_before"), f"{label}.region_before", errors)
    after = _region(report.get("region_after"), f"{label}.region_after", errors)
    if before and after and before == after:
        errors.append(f"{label}.region_after must represent a new subscription generation")

    update = report.get("update")
    if not isinstance(update, dict):
        errors.append(f"{label}.update must be an object")
    else:
        if update.get("accepted") is not True or update.get("status") != "interest_updated":
            errors.append(f"{label}.update must be an accepted interest_updated receipt")
        if update.get("source_peer_id") != update.get("authority_peer_id"):
            errors.append(f"{label}.update must be server-invoked")
        if update.get("peer_id") != peer.get("peer_id") or update.get("peer_generation") != peer.get("peer_generation_after"):
            errors.append(f"{label}.update must use the current peer generation")
        if update.get("subscription_generation") != peer.get("subscription_generation_after"):
            errors.append(f"{label}.update.subscription_generation must match the new generation")
        if update.get("snapshot_detached") is not True:
            errors.append(f"{label}.update.snapshot_detached must be true")

    stale = report.get("stale_updates")
    required = {"unauthorized_source", "stale_peer_generation", "unknown_peer", "invalid_interest_region"}
    seen: set[str] = set()
    if not isinstance(stale, list):
        errors.append(f"{label}.stale_updates must be an array")
    else:
        for index, rejection in enumerate(stale):
            prefix = f"{label}.stale_updates[{index}]"
            status = rejection.get("status") if isinstance(rejection, dict) else None
            if status in required:
                seen.add(status)
            else:
                errors.append(f"{prefix}.status is not a required interest rejection")
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
            if isinstance(rejection, dict) and rejection.get("subscription_generation_changed") is not False:
                errors.append(f"{prefix}.subscription_generation_changed must be false")
        for status in sorted(required - seen):
            errors.append(f"{label}.stale_updates must include {status}")
    return errors


def validate_generation_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_generation(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("interest", type=Path)
    args = parser.parse_args()
    errors = validate_generation_file(args.interest)
    if errors:
        print("NETWORK_PEER_INTEREST_GENERATION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_PEER_INTEREST_GENERATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
