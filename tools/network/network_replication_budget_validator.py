#!/usr/bin/env python3
"""Validate native replication bandwidth-budget evidence.

This gate consumes a capture report rather than inventing network metrics.  It
checks that every peer has a bounded measurement window, derives rates from
byte/packet counters, enforces packet-size and stale-drop ceilings, and
requires explicit native provenance.  Dummy loopback or estimated numbers are
not accepted as evidence for the Windows multiplayer budget.
"""

from __future__ import annotations

import argparse
import json
import math
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_NATIVE_KINDS = {"native_windows_two_client_soak", "native_windows_capture"}


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _positive_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0


def _finite_number(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
        and value >= 0
    )


def _peer_rate(peer: dict[str, Any], key: str) -> float | None:
    seconds = peer.get("measurement_seconds")
    value = peer.get(key)
    if not _positive_number(seconds) or not _non_negative_int(value):
        return None
    return float(value) / float(seconds)


def validate_report(report: Any, label: str = "report") -> list[str]:
    """Return structural and provenance errors for one capture report."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if report.get("measurement_scope") != "native_transport_replication_counters_per_peer":
        errors.append(f"{label}.measurement_scope is not the replication-counter scope")
    if report.get("measurement_mode") != "captured":
        errors.append(f"{label}.measurement_mode must be captured; estimates are not evidence")
    provenance = report.get("native_provenance")
    if not isinstance(provenance, dict):
        errors.append(f"{label}.native_provenance must be an object")
    else:
        if provenance.get("capture_kind") not in _NATIVE_KINDS:
            errors.append(f"{label}.native_provenance.capture_kind must identify native Windows capture")
        if provenance.get("platform") != "windows":
            errors.append(f"{label}.native_provenance.platform must be windows")
        if provenance.get("transport") not in {"enet", "udp"}:
            errors.append(f"{label}.native_provenance.transport must be enet or udp")
        if not isinstance(provenance.get("build_id"), str) or not provenance["build_id"].strip():
            errors.append(f"{label}.native_provenance.build_id must be non-empty")
        digest = provenance.get("capture_sha256")
        if not isinstance(digest, str) or not _SHA256.fullmatch(digest):
            errors.append(f"{label}.native_provenance.capture_sha256 must be lowercase SHA-256")
        if provenance.get("client_count") != 2:
            errors.append(f"{label}.native_provenance.client_count must be 2")

    peers = report.get("peers")
    if not isinstance(peers, list) or not peers:
        errors.append(f"{label}.peers must be a non-empty array")
        peers = []
    seen: set[int] = set()
    for index, peer in enumerate(peers):
        prefix = f"{label}.peers[{index}]"
        if not isinstance(peer, dict):
            errors.append(f"{prefix} must be an object")
            continue
        peer_id = peer.get("peer_id")
        if not _non_negative_int(peer_id) or peer_id in seen:
            errors.append(f"{prefix}.peer_id must be a unique non-negative integer")
        else:
            seen.add(peer_id)
        seconds = peer.get("measurement_seconds")
        if not _positive_number(seconds):
            errors.append(f"{prefix}.measurement_seconds must be positive")
        for key in ("sent_bytes", "received_bytes", "sent_packets", "received_packets", "stale_drops"):
            if not _non_negative_int(peer.get(key)):
                errors.append(f"{prefix}.{key} must be a non-negative integer")
        if _non_negative_int(peer.get("stale_drops")) and _non_negative_int(peer.get("received_packets")) and peer["stale_drops"] > peer["received_packets"]:
            errors.append(f"{prefix}.stale_drops cannot exceed received_packets")
        sizes = peer.get("packet_sizes")
        if not isinstance(sizes, dict):
            errors.append(f"{prefix}.packet_sizes must be an object")
        else:
            for key in ("max_bytes", "p95_bytes"):
                if not _non_negative_int(sizes.get(key)):
                    errors.append(f"{prefix}.packet_sizes.{key} must be a non-negative integer")
            if _non_negative_int(sizes.get("p95_bytes")) and _non_negative_int(sizes.get("max_bytes")) and sizes["p95_bytes"] > sizes["max_bytes"]:
                errors.append(f"{prefix}.packet_sizes.p95_bytes cannot exceed max_bytes")
        if peer.get("metrics_source") != "transport_counter_capture":
            errors.append(f"{prefix}.metrics_source must be transport_counter_capture")
    return errors


def validate_budget(report: Any, budgets: Any) -> list[str]:
    """Return errors when captured per-peer replication metrics exceed budgets."""
    errors = validate_report(report)
    if not isinstance(budgets, dict):
        return errors + ["replication budgets must be an object"]
    peers = report.get("peers", []) if isinstance(report, dict) else []
    limits = {
        "max_egress_bytes_per_second": budgets.get("max_egress_bytes_per_second"),
        "max_ingress_bytes_per_second": budgets.get("max_ingress_bytes_per_second"),
        "max_egress_packets_per_second": budgets.get("max_egress_packets_per_second"),
        "max_ingress_packets_per_second": budgets.get("max_ingress_packets_per_second"),
        "max_packet_bytes": budgets.get("max_packet_bytes"),
        "max_stale_drop_rate": budgets.get("max_stale_drop_rate"),
    }
    for key, limit in limits.items():
        if not _finite_number(limit):
            errors.append(f"replication budget {key} must be a non-negative number")
    if not isinstance(peers, list):
        return errors
    for peer in peers:
        if not isinstance(peer, dict):
            continue
        peer_id = peer.get("peer_id", "?")
        rates = {
            "egress_bytes_per_second": _peer_rate(peer, "sent_bytes"),
            "ingress_bytes_per_second": _peer_rate(peer, "received_bytes"),
            "egress_packets_per_second": _peer_rate(peer, "sent_packets"),
            "ingress_packets_per_second": _peer_rate(peer, "received_packets"),
        }
        for rate_key, actual in rates.items():
            limit = limits["max_" + rate_key]
            if actual is not None and _finite_number(limit) and actual > float(limit):
                errors.append(f"peer {peer_id} {rate_key} exceeds budget ({actual:.3f} > {float(limit):.3f})")
        sizes = peer.get("packet_sizes", {})
        maximum = sizes.get("max_bytes") if isinstance(sizes, dict) else None
        if _non_negative_int(maximum) and _finite_number(limits["max_packet_bytes"]) and maximum > limits["max_packet_bytes"]:
            errors.append(f"peer {peer_id} max packet size exceeds budget ({maximum} > {limits['max_packet_bytes']})")
        stale = peer.get("stale_drops")
        received = peer.get("received_packets")
        if _non_negative_int(stale) and _non_negative_int(received) and received > 0 and _finite_number(limits["max_stale_drop_rate"]):
            rate = float(stale) / float(received)
            if rate > float(limits["max_stale_drop_rate"]):
                errors.append(f"peer {peer_id} stale drop rate exceeds budget ({rate:.6f} > {float(limits['max_stale_drop_rate']):.6f})")
    return errors


validate_capture = validate_budget


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--budgets", required=True, type=Path)
    args = parser.parse_args()
    errors = validate_budget(json.loads(args.report.read_text(encoding="utf-8")), json.loads(args.budgets.read_text(encoding="utf-8")))
    if errors:
        print("NETWORK_REPLICATION_BUDGET_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_REPLICATION_BUDGET_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
