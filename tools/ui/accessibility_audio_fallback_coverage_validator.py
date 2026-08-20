#!/usr/bin/env python3
"""Validate caption/visual fallback coverage for authored audio cue families."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "accessibility_audio_fallback_coverage_v1"
REQUIRED_FAMILIES = {"combat", "station", "planetary_surface", "ui_feedback"}
REQUIRED_CHANNELS = {"captions", "visual_state"}
STATUSES = {"AUTOMATED_PASS", "OPEN", "FAILED"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _paths(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_ledger(ledger: Any) -> list[str]:
    if not isinstance(ledger, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if ledger.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    source = ledger.get("source")
    if not isinstance(source, dict):
        errors.append("source must be an object")
        source = {}
    for key in ("revision", "caption_owner", "evidence_bundle"):
        if not _text(source.get(key)):
            errors.append(f"source.{key} is required")
    if ledger.get("hardware_review") != "OPEN":
        errors.append("hardware_review must be OPEN until physical review is recorded")
    if ledger.get("claim") != "AUTOMATED_FALLBACK_ONLY":
        errors.append("claim must be AUTOMATED_FALLBACK_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    rows = ledger.get("families")
    if not isinstance(rows, list) or not rows:
        errors.append("families must be a non-empty array")
        rows = []
    seen: set[str] = set()
    for index, row in enumerate(rows):
        prefix = f"families[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        family = row.get("family")
        if family not in REQUIRED_FAMILIES:
            errors.append(f"{prefix}.family is invalid")
        elif family in seen:
            errors.append(f"{prefix}.family is duplicated")
        else:
            seen.add(family)
        if row.get("status") not in STATUSES:
            errors.append(f"{prefix}.status is invalid")
        channels = row.get("fallback_channels")
        if not isinstance(channels, list) or any(not _text(item) for item in channels) or len(set(channels)) != len(channels):
            errors.append(f"{prefix}.fallback_channels must be a unique list of strings")
        elif not REQUIRED_CHANNELS.issubset(channels):
            errors.append(f"{prefix}.fallback_channels must include captions and visual_state")
        for key in ("cue_ids", "contract_evidence"):
            if not _paths(row.get(key)):
                errors.append(f"{prefix}.{key} must be a non-empty unique list of paths/IDs")
        if row.get("status") == "OPEN" and not _text(row.get("notes")):
            errors.append(f"{prefix}.notes is required while status is OPEN")
    missing = REQUIRED_FAMILIES - seen
    if missing:
        errors.append(f"families must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("ACCESSIBILITY_AUDIO_FALLBACK_COVERAGE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_AUDIO_FALLBACK_COVERAGE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
