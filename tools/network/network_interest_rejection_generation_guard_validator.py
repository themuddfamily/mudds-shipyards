#!/usr/bin/env python3
"""Validate detached interest-generation rejection guard evidence.

This ledger focuses on generation fencing: stale peer/subscription updates and
replayed region writes are rejected without changing the current interest
snapshot. A matching current-generation update may commit once. No network or
runtime authority is exercised here.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_interest_rejection_generation_guard"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
REQUIRED_REJECTIONS = {"stale_peer_generation", "stale_subscription_generation", "replayed_update", "unknown_peer"}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_guard(report: Any, label: str = "guard") -> list[str]:
    """Return generation-fence and no-mutation errors for one guard ledger."""

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
        if audit.get("server_owns_interest") is not True or audit.get("server_owns_peer_generation") is not True:
            errors.append(f"{label}.audit must state server-owned interest and peer generation")
        if audit.get("client_can_mutate_interest") is not False:
            errors.append(f"{label}.audit.client_can_mutate_interest must be false")

    current = report.get("current")
    if not isinstance(current, dict):
        errors.append(f"{label}.current must be an object")
        current = {}
    if not _positive_int(current.get("peer_id")):
        errors.append(f"{label}.current.peer_id must be positive")
    for key in ("peer_generation", "subscription_generation", "last_update_sequence"):
        if not _positive_int(current.get(key)):
            errors.append(f"{label}.current.{key} must be positive")
    if not isinstance(current.get("region_digest"), str) or not current["region_digest"].strip():
        errors.append(f"{label}.current.region_digest must be non-empty")

    accepted = report.get("accepted_update")
    if not isinstance(accepted, dict):
        errors.append(f"{label}.accepted_update must be an object")
    else:
        if accepted.get("accepted") is not True or accepted.get("status") != "interest_updated":
            errors.append(f"{label}.accepted_update must be accepted interest_updated")
        if accepted.get("peer_id") != current.get("peer_id") or accepted.get("peer_generation") != current.get("peer_generation") or accepted.get("subscription_generation") != current.get("subscription_generation"):
            errors.append(f"{label}.accepted_update must use current generations")
        if accepted.get("sequence") != current.get("last_update_sequence") + 1:
            errors.append(f"{label}.accepted_update.sequence must advance exactly once")
        if accepted.get("server_committed") is not True:
            errors.append(f"{label}.accepted_update.server_committed must be true")

    attempts = report.get("rejections")
    seen: set[str] = set()
    if not isinstance(attempts, list):
        errors.append(f"{label}.rejections must be an array")
        attempts = []
    for index, attempt in enumerate(attempts):
        prefix = f"{label}.rejections[{index}]"
        if not isinstance(attempt, dict):
            errors.append(f"{prefix} must be an object")
            continue
        status = attempt.get("status")
        if status not in REQUIRED_REJECTIONS:
            errors.append(f"{prefix}.status is not a required generation rejection")
        else:
            seen.add(status)
        if attempt.get("accepted") is not False or attempt.get("server_rejected") is not True:
            errors.append(f"{prefix} must be server-rejected")
        if attempt.get("peer_id") not in {current.get("peer_id"), 0}:
            errors.append(f"{prefix}.peer_id must be current or unknown")
        for key in ("region_changed", "peer_generation_changed", "subscription_generation_changed"):
            if attempt.get(key) is not False:
                errors.append(f"{prefix}.{key} must be false")
        if attempt.get("region_digest_after") != current.get("region_digest"):
            errors.append(f"{prefix}.region_digest_after must retain current region")
        if attempt.get("peer_generation_after") != current.get("peer_generation") or attempt.get("subscription_generation_after") != current.get("subscription_generation"):
            errors.append(f"{prefix} must retain current generations")
        if status == "replayed_update" and attempt.get("attempted_sequence", current["last_update_sequence"]) > current["last_update_sequence"]:
            errors.append(f"{prefix}.attempted_sequence must not be newer than current sequence")
        if status in {"stale_peer_generation", "stale_subscription_generation"} and attempt.get("attempted_generation", current["peer_generation"]) >= current["peer_generation"]:
            errors.append(f"{prefix}.attempted_generation must be older than current peer generation")
    for status in sorted(REQUIRED_REJECTIONS - seen):
        errors.append(f"{label}.rejections must include {status}")
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    return errors


def validate_guard_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_guard(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("guard", type=Path)
    args = parser.parse_args()
    errors = validate_guard_file(args.guard)
    if errors:
        print("NETWORK_INTEREST_REJECTION_GENERATION_GUARD_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_INTEREST_REJECTION_GENERATION_GUARD_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
