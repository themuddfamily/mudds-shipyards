#!/usr/bin/env python3
"""Validate aggregate landing/cabin stale-callback cleanup summary evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_landing_cabin_cleanup_stale_callback_summary_v1"
CASES = {"landing_abort", "landing_complete", "cabin_exit", "detach_reentry"}


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
    for key in ("revision", "owner", "evidence_bundle"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if summary.get("claim") != "AUTOMATED_SUMMARY_ONLY":
        errors.append("claim must be AUTOMATED_SUMMARY_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")

    cases = summary.get("cases")
    if not isinstance(cases, list) or set(cases) != CASES:
        errors.append("cases must exactly cover landing_abort, landing_complete, cabin_exit, and detach_reentry")
    if isinstance(cases, list) and len(cases) != len(set(cases)):
        errors.append("cases must not contain duplicates")

    totals = summary.get("totals")
    if not isinstance(totals, dict):
        errors.append("totals must be an object")
        totals = {}
    for key in ("case_count", "callback_count", "rejected_count", "cleanup_count", "zero_voice_count"):
        if not _non_negative_int(totals.get(key)):
            errors.append(f"totals.{key} must be a non-negative integer")
    if isinstance(cases, list) and _non_negative_int(totals.get("case_count")) and totals["case_count"] != len(cases):
        errors.append("totals.case_count must match cases length")
    if _non_negative_int(totals.get("callback_count")) and _non_negative_int(totals.get("rejected_count")) and totals["rejected_count"] != totals["callback_count"]:
        errors.append("totals.rejected_count must equal callback_count")
    if _non_negative_int(totals.get("callback_count")) and _non_negative_int(totals.get("cleanup_count")) and totals["cleanup_count"] != totals["callback_count"]:
        errors.append("totals.cleanup_count must equal callback_count")
    if _non_negative_int(totals.get("cleanup_count")) and _non_negative_int(totals.get("zero_voice_count")) and totals["zero_voice_count"] != totals["cleanup_count"]:
        errors.append("totals.zero_voice_count must equal cleanup_count")
    if not _text(summary.get("aggregation_evidence")):
        errors.append("aggregation_evidence is required")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_LANDING_CABIN_CLEANUP_SUMMARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_LANDING_CABIN_CLEANUP_SUMMARY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
