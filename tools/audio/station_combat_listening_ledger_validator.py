#!/usr/bin/env python3
"""Validate station/combat native-listening review ledger records.

This is evidence bookkeeping, not an audio device test.  A row marked PASS
must point to a native capture and identify the reviewer, device, levels, and
listening notes; headless or Dummy evidence remains explicitly incomplete.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "OUTSTANDING", "NOT_RUN"}
CAPTURE_STATUSES = {"CAPTURED", "NOT_RUN", "FAILED"}
REQUIRED_SURFACES = {"station_music", "station_machinery", "combat_cues"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _unique_texts(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_ledger(ledger: Any, label: str = "ledger") -> list[str]:
    if not isinstance(ledger, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if ledger.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("ledger_id", "build_label", "source_commit"):
        if not _text(ledger.get(key)):
            errors.append(f"{label}.{key} is required")

    rows = ledger.get("reviews")
    if not isinstance(rows, list) or not rows:
        errors.append(f"{label}.reviews must be a non-empty array")
        rows = []
    seen_ids: set[str] = set()
    surfaces: set[str] = set()
    for index, row in enumerate(rows):
        prefix = f"{label}.reviews[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        review_id = row.get("review_id")
        if not _text(review_id):
            errors.append(f"{prefix}.review_id is required")
        elif review_id in seen_ids:
            errors.append(f"{prefix}.review_id is duplicated")
        else:
            seen_ids.add(review_id)
        surface = row.get("surface")
        if surface not in REQUIRED_SURFACES:
            errors.append(f"{prefix}.surface is invalid")
        else:
            surfaces.add(surface)
        for key in ("capture_id", "route_evidence"):
            if not _text(row.get(key)):
                errors.append(f"{prefix}.{key} is required")
        capture_status = row.get("capture_status")
        if capture_status not in CAPTURE_STATUSES:
            errors.append(f"{prefix}.capture_status is invalid")
        status = row.get("status")
        if status not in STATUSES:
            errors.append(f"{prefix}.status is invalid")
        if status == "PASS":
            for key in ("reviewer", "device", "notes"):
                if not _text(row.get(key)):
                    errors.append(f"{prefix}.{key} is required for PASS")
            for key in ("mix_levels", "distance_checks"):
                if not _unique_texts(row.get(key)):
                    errors.append(f"{prefix}.{key} must be a non-empty unique array for PASS")
            if capture_status != "CAPTURED":
                errors.append(f"{prefix}.PASS requires CAPTURED evidence")
            if row.get("backend") != "native_output":
                errors.append(f"{prefix}.PASS requires native_output backend")
        elif status in {"OUTSTANDING", "NOT_RUN"} and not _text(row.get("notes")):
            errors.append(f"{prefix}.notes is required while review is incomplete")
    missing = REQUIRED_SURFACES - surfaces
    if missing:
        errors.append(f"{label}.reviews must cover: {', '.join(sorted(missing))}")
    if ledger.get("claim") == "ALL_NATIVE_LISTENING_PASS":
        if len(rows) != len(REQUIRED_SURFACES) or any(row.get("status") != "PASS" for row in rows if isinstance(row, dict)):
            errors.append(f"{label}.claim ALL_NATIVE_LISTENING_PASS requires exactly three PASS rows")
    elif ledger.get("claim") == "OPEN_NATIVE_REVIEW":
        if not _text(ledger.get("boundary_note")):
            errors.append(f"{label}.boundary_note is required for OPEN_NATIVE_REVIEW")
    else:
        errors.append(f"{label}.claim must be ALL_NATIVE_LISTENING_PASS or OPEN_NATIVE_REVIEW")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("STATION_COMBAT_LISTENING_LEDGER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("STATION_COMBAT_LISTENING_LEDGER_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
