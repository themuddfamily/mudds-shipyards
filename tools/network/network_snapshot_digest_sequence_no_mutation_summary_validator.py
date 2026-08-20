#!/usr/bin/env python3
"""Validate summary counters for detached stale snapshot fence evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_snapshot_digest_sequence_no_mutation_summary"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return summary/detail consistency errors."""

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
    if not _non_negative_int(current.get("sequence")) or not isinstance(current.get("digest"), str) or not SHA256.fullmatch(current.get("digest", "")):
        errors.append(f"{label}.current must contain sequence and SHA-256 digest")

    attempts = report.get("attempts")
    if not isinstance(attempts, list):
        errors.append(f"{label}.attempts must be an array")
        attempts = []
    rejected = 0
    mutations = 0
    digest_rejections = 0
    sequence_rejections = 0
    for index, attempt in enumerate(attempts):
        prefix = f"{label}.attempts[{index}]"
        if not isinstance(attempt, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if attempt.get("accepted") is not False:
            errors.append(f"{prefix}.accepted must be false")
        else:
            rejected += 1
        if attempt.get("mutation_fields") != [] or attempt.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")
        kind = attempt.get("kind")
        if kind == "stale_digest":
            digest_rejections += 1
        if kind == "stale_sequence":
            sequence_rejections += 1
        if attempt.get("after_sequence") != current.get("sequence") or attempt.get("after_digest") != current.get("digest"):
            errors.append(f"{prefix} must preserve current sequence/digest")
    summary = report.get("counters")
    if not isinstance(summary, dict):
        errors.append(f"{label}.counters must be an object")
    else:
        expected = {"attempt_count": len(attempts), "rejected_count": rejected, "mutation_count": mutations, "digest_rejection_count": digest_rejections, "sequence_rejection_count": sequence_rejections}
        for key, value in expected.items():
            if summary.get(key) != value:
                errors.append(f"{label}.counters.{key} must equal detailed attempts")
    if report.get("accepted_next_sequence") != current.get("sequence", 0) + 1:
        errors.append(f"{label}.accepted_next_sequence must advance once")
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    return errors


def validate_summary_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_summary(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args()
    errors = validate_summary_file(args.summary)
    if errors:
        print("NETWORK_SNAPSHOT_DIGEST_SEQUENCE_SUMMARY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_SEQUENCE_SUMMARY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
