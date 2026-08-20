#!/usr/bin/env python3
"""Validate detached server-browser to session-admission evidence.

This gate joins the server-browser directory audit to a session-handshake
receipt. It proves that a fresh, visible entry can be handed to the server
admission seam without treating browser data as join authority. It does not
open sockets, contact a server, or make native/network performance claims.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_server_browser_session_admission"
EVIDENCE_MODE = "detached_contract_fixture"
BROWSER_POLICY = "network_server_browser_v1"
HANDSHAKE_POLICY = "network_session_handshake_v1"


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _positive_int(value: Any) -> bool:
    return _non_negative_int(value) and value > 0


def validate_evidence(report: Any, label: str = "evidence") -> list[str]:
    """Return structural and boundary errors for one admission evidence record."""

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

    browser = report.get("browser_audit")
    if not isinstance(browser, dict):
        errors.append(f"{label}.browser_audit must be an object")
    else:
        if browser.get("policy_version") != BROWSER_POLICY:
            errors.append(f"{label}.browser_audit.policy_version must be {BROWSER_POLICY}")
        for key in ("directory_owns_records",):
            if browser.get(key) is not True:
                errors.append(f"{label}.browser_audit.{key} must be true")
        for key in ("client_can_mutate_records", "browser_owns_join_authority", "uses_live_sockets"):
            if browser.get(key) is not False:
                errors.append(f"{label}.browser_audit.{key} must be false")

    snapshot = report.get("snapshot")
    if not isinstance(snapshot, dict):
        errors.append(f"{label}.snapshot must be an object")
    else:
        for key in ("directory_generation", "server_tick", "last_seen_tick"):
            if not _non_negative_int(snapshot.get(key)):
                errors.append(f"{label}.snapshot.{key} must be a non-negative integer")
        stale_after = snapshot.get("stale_after_ticks")
        if not _positive_int(stale_after):
            errors.append(f"{label}.snapshot.stale_after_ticks must be positive")
        elif _non_negative_int(snapshot.get("server_tick")) and _non_negative_int(snapshot.get("last_seen_tick")):
            age = snapshot["server_tick"] - snapshot["last_seen_tick"]
            if age < 0:
                errors.append(f"{label}.snapshot.last_seen_tick cannot be newer than server_tick")
            elif age > stale_after:
                errors.append(f"{label}.snapshot entry is stale ({age} > {stale_after})")

    admission = report.get("admission")
    if not isinstance(admission, dict):
        errors.append(f"{label}.admission must be an object")
    else:
        if admission.get("policy_version") != HANDSHAKE_POLICY:
            errors.append(f"{label}.admission.policy_version must be {HANDSHAKE_POLICY}")
        if admission.get("accepted") is not True:
            errors.append(f"{label}.admission.accepted must be true")
        if admission.get("server_authority") is not True:
            errors.append(f"{label}.admission.server_authority must be true")
        if admission.get("browser_grants_authority") is not False:
            errors.append(f"{label}.admission.browser_grants_authority must be false")
        if admission.get("client_can_mutate_authority") is not False:
            errors.append(f"{label}.admission.client_can_mutate_authority must be false")
        if admission.get("source") != "server_adapter":
            errors.append(f"{label}.admission.source must be server_adapter")
        if not isinstance(admission.get("session_id"), str) or not admission["session_id"].strip():
            errors.append(f"{label}.admission.session_id must be non-empty")
        if not _positive_int(admission.get("host_peer_id")):
            errors.append(f"{label}.admission.host_peer_id must be positive")

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
        print("NETWORK_SERVER_BROWSER_ADMISSION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SERVER_BROWSER_ADMISSION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
