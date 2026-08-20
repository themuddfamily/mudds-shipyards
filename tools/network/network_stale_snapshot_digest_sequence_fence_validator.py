#!/usr/bin/env python3
"""Validate detached snapshot digest/sequence fence evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_stale_snapshot_digest_sequence_fence"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_fence(report: Any, label: str = "fence") -> list[str]:
    """Return paired digest/sequence fence errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE), ("policy_version", POLICY_VERSION)):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    current = report.get("current")
    if not isinstance(current, dict):
        errors.append(f"{label}.current must be an object")
        current = {}
    if not _positive_int(current.get("sequence")):
        errors.append(f"{label}.current.sequence must be positive")
    if not isinstance(current.get("digest"), str) or not SHA256.fullmatch(current["digest"]):
        errors.append(f"{label}.current.digest must be lowercase SHA-256")

    accepted = report.get("accepted_next")
    if not isinstance(accepted, dict):
        errors.append(f"{label}.accepted_next must be an object")
    else:
        if accepted.get("accepted") is not True or accepted.get("status") != "snapshot_accepted":
            errors.append(f"{label}.accepted_next must be snapshot_accepted")
        if accepted.get("sequence") != current.get("sequence", 0) + 1:
            errors.append(f"{label}.accepted_next.sequence must advance exactly once")
        if not isinstance(accepted.get("digest"), str) or not SHA256.fullmatch(accepted["digest"]):
            errors.append(f"{label}.accepted_next.digest must be lowercase SHA-256")
        if accepted.get("digest") == current.get("digest"):
            errors.append(f"{label}.accepted_next.digest must change with the accepted sequence")
        if accepted.get("server_committed") is not True or accepted.get("snapshot_detached") is not True:
            errors.append(f"{label}.accepted_next must be server-committed and detached")

    rejections = report.get("rejections")
    required = {"stale_snapshot_sequence", "stale_snapshot_digest", "sequence_digest_mismatch"}
    seen: set[str] = set()
    if not isinstance(rejections, list):
        errors.append(f"{label}.rejections must be an array")
        rejections = []
    for index, rejection in enumerate(rejections):
        prefix = f"{label}.rejections[{index}]"
        if not isinstance(rejection, dict):
            errors.append(f"{prefix} must be an object")
            continue
        status = rejection.get("status")
        if status not in required:
            errors.append(f"{prefix}.status is not a required fence rejection")
        else:
            seen.add(status)
        if rejection.get("accepted") is not False or rejection.get("server_rejected") is not True or rejection.get("state_changed") is not False:
            errors.append(f"{prefix} must be rejected without state change")
        if rejection.get("current_sequence") != current.get("sequence") or rejection.get("current_digest") != current.get("digest"):
            errors.append(f"{prefix} must preserve current sequence/digest")
        if status == "stale_snapshot_sequence" and rejection.get("attempted_sequence", current["sequence"]) >= current["sequence"]:
            errors.append(f"{prefix}.attempted_sequence must be older")
        if status == "stale_snapshot_digest" and rejection.get("attempted_digest") == current.get("digest"):
            errors.append(f"{prefix}.attempted_digest must be stale")
    for status in sorted(required - seen):
        errors.append(f"{label}.rejections must include {status}")
    if report.get("client_can_mutate_fence") is not False:
        errors.append(f"{label}.client_can_mutate_fence must be false")
    return errors


def validate_fence_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_fence(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fence", type=Path)
    args = parser.parse_args()
    errors = validate_fence_file(args.fence)
    if errors:
        print("NETWORK_STALE_SNAPSHOT_DIGEST_SEQUENCE_FENCE_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_STALE_SNAPSHOT_DIGEST_SEQUENCE_FENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
