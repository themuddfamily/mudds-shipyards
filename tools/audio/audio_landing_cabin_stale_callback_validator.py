#!/usr/bin/env python3
"""Validate landing/cabin audio stale-callback quarantine evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_landing_cabin_stale_callback_v1"
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
    if ledger.get("claim") != "AUTOMATED_STALE_CALLBACK_ONLY":
        errors.append("claim must be AUTOMATED_STALE_CALLBACK_ONLY")
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
        if not _positive_int(case.get("old_epoch")) or not _positive_int(case.get("current_epoch")):
            errors.append(f"{prefix}.old_epoch and current_epoch must be positive integers")
        elif case["old_epoch"] >= case["current_epoch"]:
            errors.append(f"{prefix}.current_epoch must be newer than old_epoch")
        if not _positive_int(case.get("callback_sequence")):
            errors.append(f"{prefix}.callback_sequence must be a positive integer")
        for key in ("callback_evidence", "generation_evidence"):
            if not _text(case.get(key)):
                errors.append(f"{prefix}.{key} is required")
        for key in ("accepted", "sequence_consumed", "voice_unchanged", "binding_unchanged", "presentation_only"):
            if case.get(key) is not (False if key == "accepted" else True):
                errors.append(f"{prefix}.{key} must be {str(False).lower() if key == 'accepted' else 'true'}")
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
        print("AUDIO_LANDING_CABIN_STALE_CALLBACK_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_LANDING_CABIN_STALE_CALLBACK_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
