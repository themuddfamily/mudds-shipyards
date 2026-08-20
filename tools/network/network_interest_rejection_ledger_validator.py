#!/usr/bin/env python3
"""Validate detached stale/unauthorized interest rejection evidence.

Every failed region mutation must preserve the prior subscription snapshot and
generation. This ledger records those fail-closed receipts for the existing
replication-interest authority; it does not run a peer or live transport.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_interest_rejection_ledger"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
REQUIRED_STATUSES = {
    "unauthorized_source",
    "stale_peer_generation",
    "unknown_peer",
    "invalid_interest_region",
    "invalid_interest_capacity",
}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _snapshot(value: Any, label: str, errors: list[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return {}
    for key in ("center_digest", "region_digest"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} must be non-empty")
    if not isinstance(value.get("radius"), (int, float)) or isinstance(value.get("radius"), bool) or value["radius"] <= 0:
        errors.append(f"{label}.radius must be positive")
    if not _positive_int(value.get("max_entities")) or value["max_entities"] > 512:
        errors.append(f"{label}.max_entities must be in 1..512")
    if not _positive_int(value.get("subscription_generation")):
        errors.append(f"{label}.subscription_generation must be positive")
    return value


def validate_ledger(report: Any, label: str = "ledger") -> list[str]:
    """Return rejection completeness and no-mutation errors."""

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
        if audit.get("server_owns_interest") is not True:
            errors.append(f"{label}.audit.server_owns_interest must be true")
        if audit.get("client_can_mutate_interest") is not False:
            errors.append(f"{label}.audit.client_can_mutate_interest must be false")

    before = _snapshot(report.get("before"), f"{label}.before", errors)
    after = _snapshot(report.get("after"), f"{label}.after", errors)
    if before and after and before != after:
        errors.append(f"{label}.after must equal before after all rejected attempts")

    attempts = report.get("attempts")
    seen: set[str] = set()
    if not isinstance(attempts, list):
        errors.append(f"{label}.attempts must be an array")
        attempts = []
    for index, attempt in enumerate(attempts):
        prefix = f"{label}.attempts[{index}]"
        if not isinstance(attempt, dict):
            errors.append(f"{prefix} must be an object")
            continue
        status = attempt.get("status")
        if status not in REQUIRED_STATUSES:
            errors.append(f"{prefix}.status is not a required rejection")
        else:
            seen.add(status)
        if attempt.get("accepted") is not False or attempt.get("server_rejected") is not True:
            errors.append(f"{prefix} must be server-rejected")
        for key in ("region_changed", "subscription_generation_changed", "peer_interest_created"):
            if attempt.get(key) is not False:
                errors.append(f"{prefix}.{key} must be false")
        if attempt.get("before_region_digest") != before.get("region_digest") or attempt.get("after_region_digest") != before.get("region_digest"):
            errors.append(f"{prefix} must retain the prior region digest")
        if attempt.get("before_subscription_generation") != before.get("subscription_generation") or attempt.get("after_subscription_generation") != before.get("subscription_generation"):
            errors.append(f"{prefix} must retain the prior subscription generation")
    for status in sorted(REQUIRED_STATUSES - seen):
        errors.append(f"{label}.attempts must include {status}")
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    return errors


def validate_ledger_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_ledger(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args()
    errors = validate_ledger_file(args.ledger)
    if errors:
        print("NETWORK_INTEREST_REJECTION_LEDGER_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_INTEREST_REJECTION_LEDGER_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
