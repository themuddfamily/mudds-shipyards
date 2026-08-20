#!/usr/bin/env python3
"""Validate v7 ordering metadata for planetary visual evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_visual_evidence_ordering_digest_v7"
OPEN = {"pending", "not_performed"}
ORDER = ("hazard", "landmark", "route")


def validate_digest(value: Any, label: str = "digest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    entries = value.get("entries")
    if not isinstance(entries, list) or len(entries) != len(ORDER):
        errors.append(f"{label}.entries must contain hazard, landmark, and route in order")
        entries = entries if isinstance(entries, list) else []
    ids: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = entry.get("kind")
        if kind != ORDER[index] if index < len(ORDER) else True:
            errors.append(f"{prefix}.kind is out of order")
        if kind in ids:
            errors.append(f"{prefix}.kind must be unique")
        ids.add(kind)
        if not isinstance(entry.get("sequence"), int) or isinstance(entry.get("sequence"), bool) or entry["sequence"] != index + 1:
            errors.append(f"{prefix}.sequence must be {index + 1}")
        if not isinstance(entry.get("path"), str) or not entry["path"].startswith("res://"):
            errors.append(f"{prefix}.path must be a res:// path")
        if entry.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if value.get("digest_status") not in OPEN:
        errors.append(f"{label}.digest_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"ordering_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("digest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_digest(json.loads(args.digest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_VISUAL_ORDERING_V7_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_VISUAL_ORDERING_V7_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
