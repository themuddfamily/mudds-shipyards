#!/usr/bin/env python3
"""Validate interior/exterior ambience attenuation evidence without audition."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA = "audio_ambience_interior_attenuation_v1"
CONTEXTS = {"exterior", "interior", "cabin"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def validate_manifest(manifest: Any) -> list[str]:
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "evidence_bundle"):
        if not _text(manifest.get(key)):
            errors.append(f"{key} is required")
    if manifest.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if manifest.get("claim") != "AUTOMATED_ATTENUATION_ONLY":
        errors.append("claim must be AUTOMATED_ATTENUATION_ONLY")
    if not _text(manifest.get("boundary_note")):
        errors.append("boundary_note is required")

    rows = manifest.get("contexts")
    if not isinstance(rows, list) or not rows:
        errors.append("contexts must be a non-empty array")
        rows = []
    seen: set[str] = set()
    for index, row in enumerate(rows):
        prefix = f"contexts[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        context = row.get("context")
        if context not in CONTEXTS:
            errors.append(f"{prefix}.context is invalid")
        elif context in seen:
            errors.append(f"{prefix}.context is duplicated")
        else:
            seen.add(context)
        for key in ("policy_evidence", "routing_evidence"):
            if not _text(row.get(key)):
                errors.append(f"{prefix}.{key} is required")
        attenuation = row.get("interior_attenuation_db")
        if not _number(attenuation) or attenuation > 0 or attenuation < -80:
            errors.append(f"{prefix}.interior_attenuation_db must be between -80 and 0 dB")
        if context == "exterior" and attenuation != 0:
            errors.append(f"{prefix}.exterior attenuation must be exactly 0 dB")
        if context in {"interior", "cabin"} and attenuation == 0:
            errors.append(f"{prefix}.interior attenuation must be below 0 dB")
        if row.get("bus") != "Ambience":
            errors.append(f"{prefix}.bus must be Ambience")
        if row.get("positional") is not False:
            errors.append(f"{prefix}.positional must be false")
    missing = CONTEXTS - seen
    if missing:
        errors.append(f"contexts must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_AMBIENCE_INTERIOR_ATTENUATION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_AMBIENCE_INTERIOR_ATTENUATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
