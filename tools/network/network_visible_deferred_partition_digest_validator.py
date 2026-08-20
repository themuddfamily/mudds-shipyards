#!/usr/bin/env python3
"""Validate canonical digest evidence for a visible/deferred partition.

The digest covers the peer, server tick, candidate IDs, and all three
partition sets in canonical sorted form. It detects accidental or tampered
partition changes in detached evidence; it is not a transport integrity or
live-network claim.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_visible_deferred_partition_digest"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _ids(value: Any, label: str, errors: list[str]) -> list[str]:
    if not isinstance(value, list) or any(not isinstance(item, str) or not item.strip() for item in value):
        errors.append(f"{label} must be an array of non-empty strings")
        return []
    if value != sorted(value):
        errors.append(f"{label} must be sorted")
    if len(value) != len(set(value)):
        errors.append(f"{label} must not contain duplicates")
    return value


def canonical_partition_payload(report: dict[str, Any]) -> str:
    """Return the canonical JSON bytes represented by the partition digest."""

    payload = {
        "peer_id": report.get("peer_id"),
        "server_tick": report.get("server_tick"),
        "candidate_entity_ids": sorted(report.get("candidate_entity_ids", [])),
        "visible_entity_ids": sorted(report.get("visible_entity_ids", [])),
        "deferred_entity_ids": sorted(report.get("deferred_entity_ids", [])),
        "excluded_entity_ids": sorted(report.get("excluded_entity_ids", [])),
    }
    return json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def partition_digest(report: dict[str, Any]) -> str:
    """Compute the canonical SHA-256 partition digest."""

    return hashlib.sha256(canonical_partition_payload(report).encode("utf-8")).hexdigest()


def validate_digest(report: Any, label: str = "digest") -> list[str]:
    """Return partition coverage and digest integrity errors."""

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
    if not isinstance(report.get("peer_id"), int) or isinstance(report.get("peer_id"), bool) or report["peer_id"] <= 0:
        errors.append(f"{label}.peer_id must be positive")
    if not isinstance(report.get("server_tick"), int) or isinstance(report.get("server_tick"), bool) or report["server_tick"] < 0:
        errors.append(f"{label}.server_tick must be non-negative")

    candidates = _ids(report.get("candidate_entity_ids"), f"{label}.candidate_entity_ids", errors)
    visible = _ids(report.get("visible_entity_ids"), f"{label}.visible_entity_ids", errors)
    deferred = _ids(report.get("deferred_entity_ids"), f"{label}.deferred_entity_ids", errors)
    excluded = _ids(report.get("excluded_entity_ids"), f"{label}.excluded_entity_ids", errors)
    candidate_set = set(candidates)
    sets = (set(visible), set(deferred), set(excluded))
    if sets[0] & sets[1] or sets[0] & sets[2] or sets[1] & sets[2]:
        errors.append(f"{label} partition sets must be disjoint")
    if sets[0] | sets[1] | sets[2] != candidate_set:
        errors.append(f"{label} partition sets must cover candidates")

    digest = report.get("digest")
    if not isinstance(digest, dict):
        errors.append(f"{label}.digest must be an object")
    else:
        if digest.get("algorithm") != "sha256":
            errors.append(f"{label}.digest.algorithm must be sha256")
        expected = digest.get("expected")
        actual = digest.get("actual")
        if not isinstance(expected, str) or not SHA256.fullmatch(expected):
            errors.append(f"{label}.digest.expected must be lowercase SHA-256")
        if not isinstance(actual, str) or not SHA256.fullmatch(actual):
            errors.append(f"{label}.digest.actual must be lowercase SHA-256")
        computed = partition_digest(report)
        if isinstance(expected, str) and expected != computed:
            errors.append(f"{label}.digest.expected does not match canonical partition")
        if isinstance(actual, str) and actual != computed:
            errors.append(f"{label}.digest.actual does not match canonical partition")
        if expected != actual:
            errors.append(f"{label}.digest.expected and actual must match")
        if digest.get("canonical_payload") != canonical_partition_payload(report):
            errors.append(f"{label}.digest.canonical_payload must match canonical partition")
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    return errors


def validate_digest_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_digest(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("digest", type=Path)
    args = parser.parse_args()
    errors = validate_digest_file(args.digest)
    if errors:
        print("NETWORK_VISIBLE_DEFERRED_PARTITION_DIGEST_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_VISIBLE_DEFERRED_PARTITION_DIGEST_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
