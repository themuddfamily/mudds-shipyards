#!/usr/bin/env python3
"""Validate landing/cabin stale-binding generation evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_landing_cabin_stale_binding_generation_v1"
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
    if ledger.get("claim") != "AUTOMATED_GENERATION_ONLY":
        errors.append("claim must be AUTOMATED_GENERATION_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    rows = ledger.get("cases")
    if not isinstance(rows, list) or not rows:
        errors.append("cases must be a non-empty array")
        rows = []
    seen: set[str] = set()
    for index, row in enumerate(rows):
        prefix = f"cases[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = row.get("name")
        if name not in CASES:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen.add(name)
        for key in ("previous_generation", "active_generation", "callback_generation"):
            if not _positive_int(row.get(key)):
                errors.append(f"{prefix}.{key} must be a positive integer")
        if all(_positive_int(row.get(key)) for key in ("previous_generation", "active_generation", "callback_generation")):
            if row["active_generation"] <= row["previous_generation"]:
                errors.append(f"{prefix}.active_generation must be newer than previous_generation")
            if row["callback_generation"] != row["previous_generation"]:
                errors.append(f"{prefix}.callback_generation must equal previous_generation for stale evidence")
        for key in ("generation_evidence", "callback_evidence"):
            if not _text(row.get(key)):
                errors.append(f"{prefix}.{key} is required")
        for key in ("one_active_binding", "old_callback_rejected", "new_binding_retained", "presentation_only"):
            if row.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")
        if row.get("callback_result") is not False:
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
        print("AUDIO_LANDING_CABIN_STALE_GENERATION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_LANDING_CABIN_STALE_GENERATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
