#!/usr/bin/env python3
"""Validate detached authenticated packet schema and size audit evidence.

The audit mirrors the existing transport-security envelope limits. It checks
exact keys and bounded encoded/payload sizes for accepted fixtures, while
requiring server rejection receipts for malformed or oversized packets. It
never carries a real token, opens a socket, or claims live/native results.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_packet_schema_size_audit"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_transport_security_v1"
PACKET_KEYS = {
    "schema_version",
    "protocol_id",
    "session_generation",
    "peer_id",
    "peer_generation",
    "stream_id",
    "sequence",
    "auth_token",
    "payload",
}
REQUIRED_REJECTIONS = {
    "invalid_packet_schema",
    "packet_too_large",
    "payload_too_large",
    "invalid_stream_id",
    "invalid_sequence",
}


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _positive_int(value: Any) -> bool:
    return _non_negative_int(value) and value > 0


def validate_audit(report: Any, label: str = "audit") -> list[str]:
    """Return schema, size, and boundary errors for one packet audit."""

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
    for key in ("native_claims", "uses_live_network", "contains_auth_secret"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    limits = report.get("limits")
    max_packet = max_payload = max_stream = token_chars = None
    if not isinstance(limits, dict):
        errors.append(f"{label}.limits must be an object")
    else:
        for key in ("max_packet_bytes", "max_payload_bytes", "max_stream_id_length", "auth_token_bytes"):
            if not _positive_int(limits.get(key)):
                errors.append(f"{label}.limits.{key} must be positive")
        if _positive_int(limits.get("max_packet_bytes")):
            max_packet = limits["max_packet_bytes"]
        if _positive_int(limits.get("max_payload_bytes")):
            max_payload = limits["max_payload_bytes"]
        if _positive_int(limits.get("max_stream_id_length")):
            max_stream = limits["max_stream_id_length"]
        if _positive_int(limits.get("auth_token_bytes")):
            token_chars = limits["auth_token_bytes"] * 2

    packets = report.get("accepted_packets")
    if not isinstance(packets, list) or not packets:
        errors.append(f"{label}.accepted_packets must be a non-empty array")
        packets = []
    for index, packet in enumerate(packets):
        prefix = f"{label}.accepted_packets[{index}]"
        if not isinstance(packet, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if packet.get("accepted") is not True or packet.get("status") != "packet_accepted":
            errors.append(f"{prefix} must be an accepted packet receipt")
        keys = packet.get("keys")
        if not isinstance(keys, list) or set(keys) != PACKET_KEYS or len(keys) != len(PACKET_KEYS):
            errors.append(f"{prefix}.keys must be the exact packet schema")
        if not _positive_int(packet.get("schema_version")):
            errors.append(f"{prefix}.schema_version must be positive")
        if packet.get("protocol_id") != "mudds_shipyards":
            errors.append(f"{prefix}.protocol_id must be mudds_shipyards")
        for key in ("session_generation", "peer_id", "peer_generation"):
            if not _positive_int(packet.get(key)):
                errors.append(f"{prefix}.{key} must be positive")
        if not isinstance(packet.get("stream_id"), str) or not packet["stream_id"]:
            errors.append(f"{prefix}.stream_id must be non-empty")
        elif max_stream is not None and len(packet["stream_id"]) > max_stream:
            errors.append(f"{prefix}.stream_id exceeds max_stream_id_length")
        if not _non_negative_int(packet.get("sequence")):
            errors.append(f"{prefix}.sequence must be non-negative")
        if not _non_negative_int(packet.get("encoded_bytes")):
            errors.append(f"{prefix}.encoded_bytes must be non-negative")
        elif max_packet is not None and packet["encoded_bytes"] > max_packet:
            errors.append(f"{prefix}.encoded_bytes exceeds max_packet_bytes")
        if not _non_negative_int(packet.get("payload_bytes")):
            errors.append(f"{prefix}.payload_bytes must be non-negative")
        elif max_payload is not None and packet["payload_bytes"] > max_payload:
            errors.append(f"{prefix}.payload_bytes exceeds max_payload_bytes")
        token_length = packet.get("auth_token_hex_chars")
        if not _positive_int(token_length):
            errors.append(f"{prefix}.auth_token_hex_chars must be positive")
        elif token_chars is not None and token_length != token_chars:
            errors.append(f"{prefix}.auth_token_hex_chars must equal twice auth_token_bytes")
        if packet.get("server_validated") is not True:
            errors.append(f"{prefix}.server_validated must be true")

    rejections = report.get("rejections")
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
    else:
        for index, rejection in enumerate(rejections):
            prefix = f"{label}.rejections[{index}]"
            status = rejection.get("status") if isinstance(rejection, dict) else None
            if status not in REQUIRED_REJECTIONS:
                errors.append(f"{prefix}.status is not a required packet rejection")
            else:
                seen.add(status)
            if not isinstance(rejection, dict) or rejection.get("accepted") is not False or rejection.get("server_rejected") is not True:
                errors.append(f"{prefix} must be a server-rejected receipt")
        for status in sorted(REQUIRED_REJECTIONS - seen):
            errors.append(f"{label}.rejections must include {status}")
    return errors


def validate_audit_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_audit(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("audit", type=Path)
    args = parser.parse_args()
    errors = validate_audit_file(args.audit)
    if errors:
        print("NETWORK_PACKET_SCHEMA_SIZE_AUDIT_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_PACKET_SCHEMA_SIZE_AUDIT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
