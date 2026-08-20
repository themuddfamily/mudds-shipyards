#!/usr/bin/env python3
"""Validate cross-component audio stale-callback and re-entry evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_stale_reentry_rollup_v1"
REQUIRED_COMPONENTS = {"music_bed", "machinery_ambience", "combat_bank", "surface_binding"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_rollup(rollup: Any) -> list[str]:
    if not isinstance(rollup, dict):
        return ["rollup must be an object"]
    errors: list[str] = []
    if rollup.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "evidence_bundle"):
        if not _text(rollup.get(key)):
            errors.append(f"{key} is required")
    if rollup.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if rollup.get("claim") != "AUTOMATED_REENTRY_ONLY":
        errors.append("claim must be AUTOMATED_REENTRY_ONLY")
    if not _text(rollup.get("boundary_note")):
        errors.append("boundary_note is required")

    rows = rollup.get("components")
    if not isinstance(rows, list) or not rows:
        errors.append("components must be a non-empty array")
        rows = []
    seen: set[str] = set()
    for index, row in enumerate(rows):
        prefix = f"components[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = row.get("name")
        if name not in REQUIRED_COMPONENTS:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen.add(name)
        for key in ("detach_generation", "reentry_generation"):
            if not _positive_int(row.get(key)):
                errors.append(f"{prefix}.{key} must be a positive integer")
        if _positive_int(row.get("detach_generation")) and _positive_int(row.get("reentry_generation")) and row["reentry_generation"] <= row["detach_generation"]:
            errors.append(f"{prefix}.reentry_generation must be newer than detach_generation")
        for key in ("stale_callback_evidence", "reentry_evidence"):
            if not _text(row.get(key)):
                errors.append(f"{prefix}.{key} is required")
        for key in ("stale_callback_rejected", "old_voice_stopped", "reentry_signal_once", "new_voice_started"):
            if row.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")
        if row.get("stale_callback_result") is not False:
            errors.append(f"{prefix}.stale_callback_result must be false")
    missing = REQUIRED_COMPONENTS - seen
    if missing:
        errors.append(f"components must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    args = parser.parse_args(argv)
    errors = validate_rollup(json.loads(args.rollup.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_STALE_REENTRY_ROLLUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_STALE_REENTRY_ROLLUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
