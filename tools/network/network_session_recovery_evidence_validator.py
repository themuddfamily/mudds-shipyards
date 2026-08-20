#!/usr/bin/env python3
"""Validate detached network reconnect and session-recovery evidence.

The report joins the existing disconnect lifecycle and migration ledgers. It
requires a server rotation to advance its epochs, rejects stale recovery
attempts, and accepts only a newer peer-generation rebind with attachment
cleanup/recovery receipts. It is a contract fixture gate: no socket or native
network process is started.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_session_reconnect_recovery"
EVIDENCE_MODE = "detached_contract_fixture"
LIFECYCLE_POLICY = "network_disconnect_lifecycle_v1"
MIGRATION_POLICY = "network_session_migration_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _epoch(report: dict[str, Any], key: str, errors: list[str], label: str) -> dict[str, int] | None:
    value = report.get(key)
    if not isinstance(value, dict):
        errors.append(f"{label}.{key} must be an object")
        return None
    result: dict[str, int] = {}
    for field in ("package_generation", "session_generation", "migration_generation"):
        candidate = value.get(field)
        if not _positive_int(candidate):
            errors.append(f"{label}.{key}.{field} must be positive")
        else:
            result[field] = candidate
    return result


def validate_evidence(report: Any, label: str = "evidence") -> list[str]:
    """Return structural and generation-fence errors for one recovery report."""

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
    if report.get("lifecycle_policy") != LIFECYCLE_POLICY:
        errors.append(f"{label}.lifecycle_policy must be {LIFECYCLE_POLICY}")
    if report.get("migration_policy") != MIGRATION_POLICY:
        errors.append(f"{label}.migration_policy must be {MIGRATION_POLICY}")
    if not _positive_int(report.get("peer_id")):
        errors.append(f"{label}.peer_id must be positive")

    initial = _epoch(report, "initial_epoch", errors, label)
    rotated = _epoch(report, "rotated_epoch", errors, label)
    if initial is not None and rotated is not None:
        for field in initial:
            if rotated[field] <= initial[field]:
                errors.append(f"{label}.rotated_epoch.{field} must advance beyond initial_epoch")

    rotation = report.get("rotation")
    if not isinstance(rotation, dict):
        errors.append(f"{label}.rotation must be an object")
    else:
        if rotation.get("accepted") is not True:
            errors.append(f"{label}.rotation.accepted must be true")
        if rotation.get("status") != "server_rotated":
            errors.append(f"{label}.rotation.status must be server_rotated")
        if rotation.get("server_authority") is not True:
            errors.append(f"{label}.rotation.server_authority must be true")
        if rotation.get("rebind_required") is not True:
            errors.append(f"{label}.rotation.rebind_required must be true")

    stale = report.get("stale_attempt")
    if not isinstance(stale, dict):
        errors.append(f"{label}.stale_attempt must be an object")
    else:
        if stale.get("accepted") is not False:
            errors.append(f"{label}.stale_attempt.accepted must be false")
        statuses = stale.get("rejection_statuses")
        if not isinstance(statuses, list):
            errors.append(f"{label}.stale_attempt.rejection_statuses must be an array")
        else:
            for required in ("stale_session_generation", "stale_peer_generation"):
                if required not in statuses:
                    errors.append(f"{label}.stale_attempt.rejection_statuses must include {required}")

    rebind = report.get("rebind")
    if not isinstance(rebind, dict):
        errors.append(f"{label}.rebind must be an object")
    else:
        if rebind.get("accepted") is not True:
            errors.append(f"{label}.rebind.accepted must be true")
        if rebind.get("status") != "peer_rebound":
            errors.append(f"{label}.rebind.status must be peer_rebound")
        if rebind.get("attachments_restored") is not True:
            errors.append(f"{label}.rebind.attachments_restored must be true")
        if rebind.get("client_can_mutate_attachment") is not False:
            errors.append(f"{label}.rebind.client_can_mutate_attachment must be false")
        if not _positive_int(rebind.get("peer_generation")):
            errors.append(f"{label}.rebind.peer_generation must be positive")
        if _positive_int(report.get("peer_generation_before")) and _positive_int(rebind.get("peer_generation")) and rebind["peer_generation"] <= report["peer_generation_before"]:
            errors.append(f"{label}.rebind.peer_generation must advance beyond peer_generation_before")

    cleanup = report.get("cleanup")
    if not isinstance(cleanup, dict):
        errors.append(f"{label}.cleanup must be an object")
    else:
        if cleanup.get("accepted") is not True:
            errors.append(f"{label}.cleanup.accepted must be true")
        if cleanup.get("status") != "disconnected":
            errors.append(f"{label}.cleanup.status must be disconnected")
        for field in ("peer_removed", "interest_removed", "attachments_released"):
            if cleanup.get(field) is not True:
                errors.append(f"{label}.cleanup.{field} must be true")
        if cleanup.get("client_invoked") is not False:
            errors.append(f"{label}.cleanup.client_invoked must be false")

    return errors


def validate_evidence_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_evidence(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args()
    errors = validate_evidence_file(args.evidence)
    if errors:
        print("NETWORK_SESSION_RECOVERY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SESSION_RECOVERY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
