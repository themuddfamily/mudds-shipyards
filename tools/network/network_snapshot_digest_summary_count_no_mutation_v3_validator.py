#!/usr/bin/env python3
"""Validate v3 snapshot digest classification counts and mutation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 3
EVIDENCE_SCOPE = "network_snapshot_digest_summary_count_no_mutation_v3"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
KINDS = ("accepted", "stale_digest", "invalid_digest")


def _sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return v3 metadata, record, count, and no-mutation errors."""

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
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    expected_digest = report.get("expected_digest")
    if not _sha256(expected_digest):
        errors.append(f"{label}.expected_digest must be lowercase SHA-256")

    records = report.get("records")
    if not isinstance(records, list):
        errors.append(f"{label}.records must be an array")
        records = []
    by_kind = dict.fromkeys(KINDS, 0)
    mutation_count = 0
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = record.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind must be accepted, stale_digest, or invalid_digest")
        else:
            by_kind[kind] += 1
            expected_accepted = kind == "accepted"
            if record.get("accepted") is not expected_accepted:
                errors.append(f"{prefix}.accepted must be {str(expected_accepted).lower()}")
            digest = record.get("digest")
            if kind == "accepted" and digest != expected_digest:
                errors.append(f"{prefix}.digest must match expected_digest")
            elif kind == "stale_digest" and (not _sha256(digest) or digest == expected_digest):
                errors.append(f"{prefix}.digest must be a different lowercase SHA-256")
            elif kind == "invalid_digest" and _sha256(digest):
                errors.append(f"{prefix}.digest must be invalid")
        if record.get("mutation_fields") != [] or record.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        nested = counts.get("by_kind")
        if not isinstance(nested, dict):
            errors.append(f"{label}.counts.by_kind must be an object")
        else:
            for kind, expected in by_kind.items():
                if nested.get(kind) != expected:
                    errors.append(f"{label}.counts.by_kind.{kind} must match record counts")
        expected_counts = {
            "total": len(records),
            "rejected": by_kind["stale_digest"] + by_kind["invalid_digest"],
            "mutations": mutation_count,
        }
        for key, expected in expected_counts.items():
            if counts.get(key) != expected:
                errors.append(f"{label}.counts.{key} must match record counts")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
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
        print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_NO_MUTATION_V3_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_NO_MUTATION_V3_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
