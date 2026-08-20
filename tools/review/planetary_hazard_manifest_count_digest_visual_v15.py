#!/usr/bin/env python3
"""Validate v15 count/digest metadata for planetary visual manifests."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_manifest_count_digest_visual_v15"
OPEN = {"pending", "not_performed"}
KINDS = ("hazard", "landmark", "route")
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


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
    if not isinstance(entries, list) or len(entries) != len(KINDS):
        errors.append(f"{label}.entries must contain hazard, landmark, and route")
        entries = entries if isinstance(entries, list) else []
    seen: set[str] = set()
    counts: dict[str, int] = {}
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = entry.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in seen:
            errors.append(f"{prefix}.id must be unique")
        seen.add(ident)
        kind = entry.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        else:
            counts[kind] = counts.get(kind, 0) + 1
        if entry.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest")
        if not isinstance(entry.get("count"), int) or isinstance(entry.get("count"), bool) or entry["count"] < 1:
            errors.append(f"{prefix}.count must be positive")
        if not isinstance(entry.get("sha256"), str) or not HEX64.fullmatch(entry["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if entry.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if set(counts) != set(KINDS):
        errors.append(f"{label}.entries must cover hazard, landmark, and route")
    declared = value.get("declared_total")
    actual = sum(entry.get("count", 0) for entry in entries if isinstance(entry, dict) and isinstance(entry.get("count"), int) and not isinstance(entry.get("count"), bool))
    if not isinstance(declared, int) or isinstance(declared, bool) or declared < 3:
        errors.append(f"{label}.declared_total must be at least three")
    elif declared != actual:
        errors.append(f"{label}.declared_total must equal entry count sum")
    if value.get("count_digest_status") not in OPEN:
        errors.append(f"{label}.count_digest_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"count_digest_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_COUNT_DIGEST_V15_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_COUNT_DIGEST_V15_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
