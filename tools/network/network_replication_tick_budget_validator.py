#!/usr/bin/env python3
"""Validate detached per-tick replication batch budget evidence.

This complements the native transport-counter gate with a logical fixture
check: every server batch must respect entity and byte ceilings, account for
deferred work, and keep the client outside the authority boundary. It does
not measure a live transport or claim native performance.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_replication_tick_budget"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _positive_int(value: Any) -> bool:
    return _non_negative_int(value) and value > 0


def _sorted_unique_ids(value: Any, label: str, errors: list[str]) -> set[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        errors.append(f"{label} must be an array of non-empty strings")
        return set()
    if value != sorted(value):
        errors.append(f"{label} must be sorted")
    if len(value) != len(set(value)):
        errors.append(f"{label} must not contain duplicates")
    return set(value)


def validate_budget(report: Any, label: str = "budget") -> list[str]:
    """Return errors for a detached sequence of server replication ticks."""

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
        if audit.get("server_owns_replication_budget") is not True:
            errors.append(f"{label}.audit.server_owns_replication_budget must be true")
        if audit.get("client_can_mutate_state") is not False:
            errors.append(f"{label}.audit.client_can_mutate_state must be false")

    limits = report.get("limits")
    max_entities = max_bytes = max_deferred = None
    if not isinstance(limits, dict):
        errors.append(f"{label}.limits must be an object")
    else:
        for field in ("max_entities_per_tick", "max_bytes_per_tick", "max_deferred_entities"):
            if not _positive_int(limits.get(field)):
                errors.append(f"{label}.limits.{field} must be positive")
        if _positive_int(limits.get("max_entities_per_tick")):
            max_entities = limits["max_entities_per_tick"]
        if _positive_int(limits.get("max_bytes_per_tick")):
            max_bytes = limits["max_bytes_per_tick"]
        if _positive_int(limits.get("max_deferred_entities")):
            max_deferred = limits["max_deferred_entities"]

    ticks = report.get("ticks")
    if not isinstance(ticks, list) or not ticks:
        errors.append(f"{label}.ticks must be a non-empty array")
        return errors
    previous_tick = -1
    for index, tick in enumerate(ticks):
        prefix = f"{label}.ticks[{index}]"
        if not isinstance(tick, dict):
            errors.append(f"{prefix} must be an object")
            continue
        server_tick = tick.get("server_tick")
        if not _non_negative_int(server_tick):
            errors.append(f"{prefix}.server_tick must be non-negative")
        elif server_tick <= previous_tick:
            errors.append(f"{prefix}.server_tick must be strictly increasing")
        else:
            previous_tick = server_tick
        sent = _sorted_unique_ids(tick.get("sent_entity_ids"), f"{prefix}.sent_entity_ids", errors)
        deferred = _sorted_unique_ids(tick.get("deferred_entity_ids"), f"{prefix}.deferred_entity_ids", errors)
        if sent & deferred:
            errors.append(f"{prefix}.sent_entity_ids and deferred_entity_ids must be disjoint")
        if max_entities is not None and len(sent) > max_entities:
            errors.append(f"{prefix}.sent_entity_ids exceeds max_entities_per_tick")
        if max_deferred is not None and len(deferred) > max_deferred:
            errors.append(f"{prefix}.deferred_entity_ids exceeds max_deferred_entities")
        sent_bytes = tick.get("sent_bytes")
        if not _non_negative_int(sent_bytes):
            errors.append(f"{prefix}.sent_bytes must be non-negative")
        elif max_bytes is not None and sent_bytes > max_bytes:
            errors.append(f"{prefix}.sent_bytes exceeds max_bytes_per_tick")
        remaining = tick.get("remaining_entity_budget")
        if max_entities is not None and remaining != max_entities - len(sent):
            errors.append(f"{prefix}.remaining_entity_budget must equal configured cap minus sent count")
        if tick.get("source") != "server_adapter":
            errors.append(f"{prefix}.source must be server_adapter")
    return errors


def validate_budget_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_budget(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("budget", type=Path)
    args = parser.parse_args()
    errors = validate_budget_file(args.budget)
    if errors:
        print("NETWORK_REPLICATION_TICK_BUDGET_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_REPLICATION_TICK_BUDGET_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
