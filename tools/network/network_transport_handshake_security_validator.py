#!/usr/bin/env python3
"""Validate detached transport and handshake security evidence.

The rollup joins the existing session-handshake and authenticated-transport
ledgers. It requires one valid admission/packet path plus explicit rejection
receipts for source forgery, compatibility drift, replay, stale generations,
bad tokens, and oversized packets. It never handles a secret or opens a live
network transport.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_transport_handshake_security"
EVIDENCE_MODE = "detached_contract_fixture"
HANDSHAKE_POLICY = "network_session_handshake_v1"
TRANSPORT_POLICY = "network_transport_security_v1"
REQUIRED_REJECTIONS = {
    "protocol_mismatch",
    "spoofed_peer",
    "stale_session_generation",
    "replayed_or_out_of_order",
    "invalid_auth_token",
    "packet_too_large",
}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_rollup(report: Any, label: str = "rollup") -> list[str]:
    """Return structural and boundary errors for one security rollup."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if report.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if report.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("native_claims", "uses_live_network", "contains_secret_material"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if report.get("handshake_policy") != HANDSHAKE_POLICY:
        errors.append(f"{label}.handshake_policy must be {HANDSHAKE_POLICY}")
    if report.get("transport_policy") != TRANSPORT_POLICY:
        errors.append(f"{label}.transport_policy must be {TRANSPORT_POLICY}")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        required_true = (
            "server_owns_token_generation",
            "server_owns_replay_cursor",
            "exact_packet_schema",
            "bounded_packet_bytes",
            "forged_source_rejected",
            "stale_generation_rejected",
            "server_owns_peer_admission",
        )
        for key in required_true:
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        if audit.get("client_can_mutate_session") is not False:
            errors.append(f"{label}.audit.client_can_mutate_session must be false")

    offer = report.get("server_offer")
    if not isinstance(offer, dict):
        errors.append(f"{label}.server_offer must be an object")
    else:
        for key in ("schema_version", "protocol_version", "package_generation", "session_generation"):
            if not _positive_int(offer.get(key)):
                errors.append(f"{label}.server_offer.{key} must be positive")
        if offer.get("protocol_id") != "mudds_shipyards":
            errors.append(f"{label}.server_offer.protocol_id must be mudds_shipyards")

    hello = report.get("accepted_hello")
    if not isinstance(hello, dict):
        errors.append(f"{label}.accepted_hello must be an object")
    else:
        if hello.get("accepted") is not True or hello.get("status") != "accepted":
            errors.append(f"{label}.accepted_hello must be an accepted receipt")
        if hello.get("source_peer_id") != hello.get("peer_id"):
            errors.append(f"{label}.accepted_hello source_peer_id must match peer_id")
        if not _positive_int(hello.get("peer_generation")):
            errors.append(f"{label}.accepted_hello.peer_generation must be positive")
        if hello.get("server_authority") is not True:
            errors.append(f"{label}.accepted_hello.server_authority must be true")

    packet = report.get("accepted_packet")
    if not isinstance(packet, dict):
        errors.append(f"{label}.accepted_packet must be an object")
    else:
        if packet.get("accepted") is not True or packet.get("status") != "packet_accepted":
            errors.append(f"{label}.accepted_packet must be an accepted receipt")
        if packet.get("source_peer_id") != packet.get("peer_id"):
            errors.append(f"{label}.accepted_packet source_peer_id must match peer_id")
        if not _positive_int(packet.get("sequence")) and packet.get("sequence") != 0:
            errors.append(f"{label}.accepted_packet.sequence must be non-negative")
        if packet.get("server_authority") is not True:
            errors.append(f"{label}.accepted_packet.server_authority must be true")

    rejections = report.get("rejections")
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
    else:
        for index, rejection in enumerate(rejections):
            prefix = f"{label}.rejections[{index}]"
            if not isinstance(rejection, dict):
                errors.append(f"{prefix} must be an object")
                continue
            status = rejection.get("status")
            if status not in REQUIRED_REJECTIONS:
                errors.append(f"{prefix}.status is not a required security rejection")
            elif status in seen:
                errors.append(f"{prefix}.status must be unique")
            else:
                seen.add(status)
            if rejection.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if rejection.get("server_rejected") is not True:
                errors.append(f"{prefix}.server_rejected must be true")
        missing = REQUIRED_REJECTIONS - seen
        for status in sorted(missing):
            errors.append(f"{label}.rejections must include {status}")
    return errors


def validate_rollup_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_rollup(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    args = parser.parse_args()
    errors = validate_rollup_file(args.rollup)
    if errors:
        print("NETWORK_TRANSPORT_HANDSHAKE_SECURITY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_TRANSPORT_HANDSHAKE_SECURITY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
