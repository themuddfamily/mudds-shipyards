#!/usr/bin/env python3
"""Validate v17 completeness for planetary hazard visual digests."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_manifest_digest_completeness_visual_v17"
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}
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
    if not isinstance(entries, list) or len(entries) != 3:
        errors.append(f"{label}.entries must contain exactly three complete records")
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
        if entry.get("manifest_id") != value.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest")
        if not isinstance(entry.get("evidence_refs"), list) or not entry["evidence_refs"] or any(not isinstance(ref, str) or not ref.startswith("res://") for ref in entry.get("evidence_refs", [])):
            errors.append(f"{prefix}.evidence_refs must contain res:// paths")
        if not isinstance(entry.get("sha256"), str) or not HEX64.fullmatch(entry["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if entry.get("complete") is not False:
            errors.append(f"{prefix}.complete must remain false until review")
        if entry.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.entries must cover hazard, landmark, and route")
    if value.get("completeness_status") not in OPEN:
        errors.append(f"{label}.completeness_status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"completeness_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_COMPLETENESS_V17_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_COMPLETENESS_V17_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
