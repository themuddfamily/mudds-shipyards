#!/usr/bin/env python3
"""Validate count-only evidence for detached snapshot digest checks."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_snapshot_digest_summary_count"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
KINDS = {"accepted", "stale_digest", "invalid_digest"}


def _sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return metadata, digest classification, and aggregate count errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]

    expected_metadata = (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
    )
    for key, expected in expected_metadata:
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network", "snapshot_detached"):
        expected = True if key == "snapshot_detached" else False
        if report.get(key) is not expected:
            errors.append(f"{label}.{key} must be {str(expected).lower()}")

    expected_digest = report.get("expected_digest")
    if not _sha256(expected_digest):
        errors.append(f"{label}.expected_digest must be lowercase SHA-256")

    observations = report.get("observations")
    if not isinstance(observations, list):
        errors.append(f"{label}.observations must be an array")
        observations = []

    counts = {"accepted": 0, "stale_digest": 0, "invalid_digest": 0}
    for index, observation in enumerate(observations):
        prefix = f"{label}.observations[{index}]"
        if not isinstance(observation, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = observation.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind must be accepted, stale_digest, or invalid_digest")
            continue
        counts[kind] += 1
        digest = observation.get("digest")
        if kind == "accepted":
            if observation.get("accepted") is not True:
                errors.append(f"{prefix}.accepted must be true")
            if digest != expected_digest:
                errors.append(f"{prefix}.digest must match expected_digest")
        elif kind == "stale_digest":
            if observation.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if not _sha256(digest) or digest == expected_digest:
                errors.append(f"{prefix}.digest must be a different lowercase SHA-256")
        else:
            if observation.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if _sha256(digest):
                errors.append(f"{prefix}.digest must be invalid")

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
        }
        for key, expected in expected_counts.items():
            if summary.get(key) != expected:
                errors.append(f"{label}.summary.{key} must match observation counts")
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
        print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_SUMMARY_COUNT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
