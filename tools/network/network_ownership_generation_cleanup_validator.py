#!/usr/bin/env python3
"""Validate detached ship ownership generation cleanup evidence.

The ledger proves that disconnect release clears an owner's ship, retirement
removes the old lifecycle generation, and re-registration requires a newer
generation before ownership can be claimed again. It does not run a ship,
session, or live network.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_ownership_generation_cleanup"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_ship_ownership_authority_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_ledger(report: Any, label: str = "ledger") -> list[str]:
    """Return ownership release, retirement, and generation-fence errors."""

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
        for key in ("server_owns_ship_claims", "server_owns_ship_generations", "server_owns_disconnect_cleanup"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        if audit.get("client_can_mutate_ownership") is not False:
            errors.append(f"{label}.audit.client_can_mutate_ownership must be false")

    before = report.get("before")
    if not isinstance(before, dict):
        errors.append(f"{label}.before must be an object")
        before = {}
    for key in ("ship_id",):
        if not isinstance(before.get(key), str) or not before[key].strip():
            errors.append(f"{label}.before.{key} must be non-empty")
    for key in ("ship_generation", "owner_peer_id", "ownership_generation"):
        checker = _positive_int if key == "ship_generation" else _non_negative_int
        if not checker(before.get(key)):
            errors.append(f"{label}.before.{key} has an invalid value")
    if before.get("owner_peer_id", 0) == 0:
        errors.append(f"{label}.before.owner_peer_id must identify the current owner")
    if not _non_negative_int(before.get("last_request_sequence")):
        errors.append(f"{label}.before.last_request_sequence must be non-negative")

    release = report.get("release")
    if not isinstance(release, dict):
        errors.append(f"{label}.release must be an object")
        release = {}
    if release.get("accepted") is not True or release.get("status") != "peer_released":
        errors.append(f"{label}.release must be an accepted peer_released receipt")
    if release.get("server_committed") is not True or release.get("client_invoked") is not False:
        errors.append(f"{label}.release must be server-committed and client-inaccessible")
    if release.get("peer_id") != before.get("owner_peer_id"):
        errors.append(f"{label}.release.peer_id must match the prior owner")
    if not isinstance(release.get("ship_ids"), list) or before.get("ship_id") not in release.get("ship_ids", []):
        errors.append(f"{label}.release.ship_ids must include the released ship")
    if release.get("owner_after") != 0:
        errors.append(f"{label}.release.owner_after must be zero")
    if _non_negative_int(before.get("ownership_generation")) and release.get("ownership_generation_after") != before["ownership_generation"] + 1:
        errors.append(f"{label}.release.ownership_generation_after must advance exactly once")
    if release.get("request_sequence_after") != -1:
        errors.append(f"{label}.release.request_sequence_after must reset to -1")

    retire = report.get("retire")
    if not isinstance(retire, dict):
        errors.append(f"{label}.retire must be an object")
        retire = {}
    if retire.get("accepted") is not True or retire.get("status") != "retired":
        errors.append(f"{label}.retire must be an accepted retired receipt")
    if retire.get("server_committed") is not True or retire.get("ship_id") != before.get("ship_id"):
        errors.append(f"{label}.retire must server-retire the original ship ID")
    if retire.get("ship_generation") != before.get("ship_generation"):
        errors.append(f"{label}.retire.ship_generation must match the retired generation")
    if retire.get("present_after") is not False:
        errors.append(f"{label}.retire.present_after must be false")

    reuse = report.get("reuse")
    if not isinstance(reuse, dict):
        errors.append(f"{label}.reuse must be an object")
        reuse = {}
    if reuse.get("accepted") is not True or reuse.get("status") != "registered":
        errors.append(f"{label}.reuse must be an accepted registered receipt")
    if reuse.get("server_committed") is not True or reuse.get("ship_id") != before.get("ship_id"):
        errors.append(f"{label}.reuse must re-register the same ship ID server-side")
    if not _positive_int(reuse.get("ship_generation")) or reuse.get("ship_generation", 0) <= before.get("ship_generation", 0):
        errors.append(f"{label}.reuse.ship_generation must be newer than the retired generation")
    if reuse.get("owner_peer_id") != 0 or reuse.get("ownership_generation") != 0:
        errors.append(f"{label}.reuse must begin unowned with zero ownership generation")

    required_rejections = {"unauthorized_source", "stale_ship_generation", "stale_request_sequence", "owner_mismatch"}
    rejections = report.get("rejections")
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
    else:
        for index, rejection in enumerate(rejections):
            prefix = f"{label}.rejections[{index}]"
            status = rejection.get("status") if isinstance(rejection, dict) else None
            if status in required_rejections:
                seen.add(status)
            else:
                errors.append(f"{prefix}.status is not a required ownership rejection")
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
        for status in sorted(required_rejections - seen):
            errors.append(f"{label}.rejections must include {status}")
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
        print("NETWORK_OWNERSHIP_GENERATION_CLEANUP_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_OWNERSHIP_GENERATION_CLEANUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
