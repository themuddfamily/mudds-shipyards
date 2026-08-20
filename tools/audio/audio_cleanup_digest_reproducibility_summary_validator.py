#!/usr/bin/env python3
"""Validate aggregate reproducibility summary metadata for audio cleanup digests."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_reproducibility_summary_v1"


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if summary.get("claim") != "AUTOMATED_REPRODUCIBILITY_SUMMARY_ONLY":
        errors.append("claim must be AUTOMATED_REPRODUCIBILITY_SUMMARY_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")

    totals = summary.get("totals")
    if not isinstance(totals, dict):
        errors.append("totals must be an object")
        totals = {}
    for key in ("run_count", "independent_run_count", "matching_digest_count", "input_agreement_count"):
        if not _non_negative_int(totals.get(key)):
            errors.append(f"totals.{key} must be a non-negative integer")
    if _non_negative_int(totals.get("run_count")) and totals["run_count"] < 2:
        errors.append("totals.run_count must be at least 2")
    if all(_non_negative_int(totals.get(key)) for key in ("run_count", "independent_run_count", "matching_digest_count", "input_agreement_count")):
        if totals["independent_run_count"] != totals["run_count"]:
            errors.append("totals.independent_run_count must equal run_count")
        if totals["matching_digest_count"] != totals["run_count"]:
            errors.append("totals.matching_digest_count must equal run_count")
        if totals["input_agreement_count"] != totals["run_count"]:
            errors.append("totals.input_agreement_count must equal run_count")
    if summary.get("digest_status") != "MATCHING":
        errors.append("digest_status must be MATCHING")
    if summary.get("input_status") != "AGREED":
        errors.append("input_status must be AGREED")
    if summary.get("reproducible") is not True:
        errors.append("reproducible must be true")
    if not _text(summary.get("aggregation_evidence")):
        errors.append("aggregation_evidence is required")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_DIGEST_REPRO_SUMMARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_DIGEST_REPRO_SUMMARY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
