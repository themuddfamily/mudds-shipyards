#!/usr/bin/env python3
"""Validate v2 snapshot digest count evidence with a no-mutation guard."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 2
EVIDENCE_SCOPE = "network_snapshot_digest_summary_count_no_mutation_v2"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
KINDS = {"accepted", "stale_digest", "invalid_digest"}


def _sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return metadata, classification, count, and mutation errors."""

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
    if report.get("snapshot_detached") is not True:
        errors.append(f"{label}.snapshot_detached must be true")
    if report.get("no_mutation_guarantee") is not True:
        errors.append(f"{label}.no_mutation_guarantee must be true")

    expected_digest = report.get("expected_digest")
    if not _sha256(expected_digest):
        errors.append(f"{label}.expected_digest must be lowercase SHA-256")

    observations = report.get("observations")
    if not isinstance(observations, list):
        errors.append(f"{label}.observations must be an array")
        observations = []
    counts = {"accepted": 0, "stale_digest": 0, "invalid_digest": 0}
    mutation_count = 0
    for index, observation in enumerate(observations):
        prefix = f"{label}.observations[{index}]"
        if not isinstance(observation, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = observation.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind must be accepted, stale_digest, or invalid_digest")
        else:
            counts[kind] += 1
            accepted = kind == "accepted"
            if observation.get("accepted") is not accepted:
                errors.append(f"{prefix}.accepted must be {str(accepted).lower()}")
            digest = observation.get("digest")
            if kind == "accepted" and digest != expected_digest:
                errors.append(f"{prefix}.digest must match expected_digest")
            elif kind == "stale_digest" and (not _sha256(digest) or digest == expected_digest):
                errors.append(f"{prefix}.digest must be a different lowercase SHA-256")
            elif kind == "invalid_digest" and _sha256(digest):
                errors.append(f"{prefix}.digest must be invalid")
        if observation.get("mutation_fields") != [] or observation.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    summary = report.get("summary")
    if not isinstance(summary, dict):
        errors.append(f"{label}.summary must be an object")
    else:
        expected_counts = {
            "total": len(observations),
            "accepted": counts["accepted"],
            "stale_digest_rejected": counts["stale_digest"],
            "invalid_digest_rejected": counts["invalid_digest"],
            "rejected": counts["stale_digest"] + counts["invalid_digest"],
            "mutation_count": mutation_count,
        }
        for key, expected in expected_counts.items():
            if summary.get(key) != expected:
                errors.append(f"{label}.summary.{key} must match observation counts")
        if summary.get("mutation_count") != 0:
            errors.append(f"{label}.summary.mutation_count must be zero")
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
        print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_NO_MUTATION_V2_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_NO_MUTATION_V2_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
