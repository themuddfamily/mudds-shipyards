#!/usr/bin/env python3
"""Validate v4 detached snapshot digest totals and no-mutation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 4
EVIDENCE_SCOPE = "network_snapshot_digest_summary_count_no_mutation_v4"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
CLASSIFICATIONS = {"accepted", "digest_mismatch", "invalid_digest"}


def _sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return v4 metadata, entry classification, totals, and mutation errors."""

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

    entries = report.get("entries")
    if not isinstance(entries, list):
        errors.append(f"{label}.entries must be an array")
        entries = []
    counts = {classification: 0 for classification in CLASSIFICATIONS}
    mutation_count = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        classification = entry.get("classification")
        if classification not in CLASSIFICATIONS:
            errors.append(f"{prefix}.classification must be accepted, digest_mismatch, or invalid_digest")
        else:
            counts[classification] += 1
            accepted = classification == "accepted"
            if entry.get("accepted") is not accepted:
                errors.append(f"{prefix}.accepted must be {str(accepted).lower()}")
            digest = entry.get("digest")
            if classification == "accepted" and digest != expected_digest:
                errors.append(f"{prefix}.digest must match expected_digest")
            elif classification == "digest_mismatch" and (not _sha256(digest) or digest == expected_digest):
                errors.append(f"{prefix}.digest must differ from expected_digest")
            elif classification == "invalid_digest" and _sha256(digest):
                errors.append(f"{prefix}.digest must be invalid")
        if entry.get("mutation_fields") != [] or entry.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    totals = report.get("totals")
    if not isinstance(totals, dict):
        errors.append(f"{label}.totals must be an object")
    else:
        expected_totals = {
            "entries": len(entries),
            "accepted": counts["accepted"],
            "digest_mismatches": counts["digest_mismatch"],
            "invalid_digests": counts["invalid_digest"],
            "rejected": counts["digest_mismatch"] + counts["invalid_digest"],
            "mutations": mutation_count,
        }
        for key, expected in expected_totals.items():
            if totals.get(key) != expected:
                errors.append(f"{label}.totals.{key} must match entry counts")
        if totals.get("mutations") != 0:
            errors.append(f"{label}.totals.mutations must be zero")
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
        print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_NO_MUTATION_V4_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_NO_MUTATION_V4_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
