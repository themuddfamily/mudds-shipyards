#!/usr/bin/env python3
"""Validate v18 completeness/authority metadata for planetary evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_completeness_authority_visual_v18"
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "manifest_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    entries = value.get("entries")
    if not isinstance(entries, list) or len(entries) != 3:
        errors.append(f"{label}.entries must contain exactly three records")
        entries = entries if isinstance(entries, list) else []
    kinds: set[str] = set()
    ids: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = entry.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = entry.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if entry.get("authority") is not False:
            errors.append(f"{prefix}.authority must be false")
        if entry.get("complete") is not False:
            errors.append(f"{prefix}.complete must remain false")
        if entry.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.entries must cover hazard, landmark, and route")
    authority = value.get("authority_exclusions")
    required = {"hazard_runtime", "route_runtime", "visual_approval", "native_render", "human_signoff"}
    if not isinstance(authority, list) or not required.issubset(set(authority)):
        errors.append(f"{label}.authority_exclusions must preserve runtime and review exclusions")
    if value.get("authority_status") not in OPEN:
        errors.append(f"{label}.authority_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_AUTHORITY_V18_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_AUTHORITY_V18_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
