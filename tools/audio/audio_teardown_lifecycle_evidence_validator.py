#!/usr/bin/env python3
"""Validate audio detach/teardown lifecycle evidence and stale-callback guards."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_teardown_lifecycle_evidence_v1"
REQUIRED_COMPONENTS = {"station_music", "station_machinery", "combat_presentation", "planetary_surface"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(ledger: Any) -> list[str]:
    if not isinstance(ledger, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if ledger.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "lifecycle_owner", "evidence_bundle"):
        if not _text(ledger.get(key)):
            errors.append(f"{key} is required")
    if ledger.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if ledger.get("claim") != "AUTOMATED_LIFECYCLE_ONLY":
        errors.append("claim must be AUTOMATED_LIFECYCLE_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    rows = ledger.get("components")
    if not isinstance(rows, list) or not rows:
        errors.append("components must be a non-empty array")
        rows = []
    seen: set[str] = set()
    for index, row in enumerate(rows):
        prefix = f"components[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        component = row.get("component")
        if component not in REQUIRED_COMPONENTS:
            errors.append(f"{prefix}.component is invalid")
        elif component in seen:
            errors.append(f"{prefix}.component is duplicated")
        else:
            seen.add(component)
        for key in ("attach_evidence", "detach_evidence", "reentry_evidence"):
            if not _text(row.get(key)):
                errors.append(f"{prefix}.{key} is required")
        for key in ("detach_stops_voices", "detach_clears_transients", "stale_callback_rejected", "reentry_reconnects_once"):
            if row.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")
        if not _text(row.get("notes")):
            errors.append(f"{prefix}.notes is required")
    missing = REQUIRED_COMPONENTS - seen
    if missing:
        errors.append(f"components must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_TEARDOWN_LIFECYCLE_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_TEARDOWN_LIFECYCLE_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
