#!/usr/bin/env python3
"""Validate aggregate snapshot digest/sequence no-mutation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_snapshot_digest_sequence_summary_no_mutation"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_summary(report: Any, label: str = "summary") -> list[str]:
    """Return aggregate/detail no-mutation consistency errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE), ("policy_version", POLICY_VERSION)):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    initial = report.get("initial")
    final = report.get("final")
    for name, state in (("initial", initial), ("final", final)):
        if not isinstance(state, dict):
            errors.append(f"{label}.{name} must be an object")
            continue
        if not _non_negative_int(state.get("sequence")):
            errors.append(f"{label}.{name}.sequence must be non-negative")
        if not isinstance(state.get("digest"), str) or not SHA256.fullmatch(state.get("digest", "")):
            errors.append(f"{label}.{name}.digest must be lowercase SHA-256")

    details = report.get("details")
    if not isinstance(details, list):
        errors.append(f"{label}.details must be an array")
        details = []
    digest_count = sequence_count = rejected_count = mutation_count = 0
    for index, detail in enumerate(details):
        prefix = f"{label}.details[{index}]"
        if not isinstance(detail, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = detail.get("kind")
        if kind == "stale_digest":
            digest_count += 1
        elif kind == "stale_sequence":
            sequence_count += 1
        else:
            errors.append(f"{prefix}.kind must be stale_digest or stale_sequence")
        if detail.get("accepted") is not False:
            errors.append(f"{prefix}.accepted must be false")
        else:
            rejected_count += 1
        if detail.get("mutation_fields") != [] or detail.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
        if detail.get("after_sequence") != final.get("sequence") or detail.get("after_digest") != final.get("digest"):
            errors.append(f"{prefix} must match final state")

    counters = report.get("summary")
    if not isinstance(counters, dict):
        errors.append(f"{label}.summary must be an object")
    else:
        expected = {"total_attempts": len(details), "stale_rejections": rejected_count, "state_mutations": mutation_count, "digest_rejections": digest_count, "sequence_rejections": sequence_count}
        for key, value in expected.items():
            if counters.get(key) != value:
                errors.append(f"{label}.summary.{key} must match detail counts")
        if counters.get("accepted_updates") != 1:
            errors.append(f"{label}.summary.accepted_updates must be 1")
    if _non_negative_int(initial.get("sequence")) and _non_negative_int(final.get("sequence")) and final["sequence"] != initial["sequence"] + 1:
        errors.append(f"{label}.final.sequence must advance once for the accepted update")
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
        print("NETWORK_SNAPSHOT_DIGEST_SEQUENCE_SUMMARY_NO_MUTATION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DIGEST_SEQUENCE_SUMMARY_NO_MUTATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
