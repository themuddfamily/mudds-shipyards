#!/usr/bin/env python3
"""Validate landing/cabin audio cleanup-generation evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_landing_cabin_cleanup_generation_v1"
CASES = {"landing_abort", "landing_complete", "cabin_exit", "detach_reentry"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_ledger(ledger: Any) -> list[str]:
    if not isinstance(ledger, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if ledger.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "evidence_bundle"):
        if not _text(ledger.get(key)):
            errors.append(f"{key} is required")
    if ledger.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if ledger.get("claim") != "AUTOMATED_CLEANUP_GENERATION_ONLY":
        errors.append("claim must be AUTOMATED_CLEANUP_GENERATION_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    cases = ledger.get("cases")
    if not isinstance(cases, list) or not cases:
        errors.append("cases must be a non-empty array")
        cases = []
    seen: set[str] = set()
    for index, case in enumerate(cases):
        prefix = f"cases[{index}]"
        if not isinstance(case, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = case.get("name")
        if name not in CASES:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen.add(name)
        for key in ("binding_generation", "cleanup_generation", "callback_generation"):
            if not _positive_int(case.get(key)):
                errors.append(f"{prefix}.{key} must be a positive integer")
        if all(_positive_int(case.get(key)) for key in ("binding_generation", "cleanup_generation", "callback_generation")):
            if case["cleanup_generation"] <= case["binding_generation"]:
                errors.append(f"{prefix}.cleanup_generation must be newer than binding_generation")
            if case["callback_generation"] != case["binding_generation"]:
                errors.append(f"{prefix}.callback_generation must equal binding_generation for stale evidence")
        for key in ("cleanup_evidence", "generation_evidence"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} is required")
        for key in ("cleanup_committed", "old_callback_rejected", "voices_zero", "presentation_only"):
            if case.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")
        if case.get("callback_result") is not False:
            errors.append(f"{prefix}.callback_result must be false")
    missing = CASES - seen
    if missing:
        errors.append(f"cases must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_LANDING_CABIN_CLEANUP_GENERATION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_LANDING_CABIN_CLEANUP_GENERATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
