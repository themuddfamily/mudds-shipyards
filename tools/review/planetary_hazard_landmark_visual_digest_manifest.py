#!/usr/bin/env python3
"""Validate a visual digest manifest for planetary hazard landmarks."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_digest_manifest_v1"
OPEN = {"pending", "not_performed"}
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
REQUIRED_KINDS = {"hazard", "landmark", "route"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    items = value.get("items")
    if not isinstance(items, list) or not items:
        errors.append(f"{label}.items must contain digest items")
        items = []
    ids: set[str] = set()
    kinds: set[str] = set()
    for index, item in enumerate(items):
        prefix = f"{label}.items[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = item.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = item.get("kind")
        if kind not in REQUIRED_KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if not _text(item.get("path")) or not item["path"].startswith("res://"):
            errors.append(f"{prefix}.path must be a res:// path")
        if not isinstance(item.get("sha256"), str) or not SHA256.fullmatch(item["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if item.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    if not REQUIRED_KINDS.issubset(kinds):
        errors.append(f"{label}.items must cover hazard, landmark, and route kinds")
    aggregate = value.get("aggregate")
    if not isinstance(aggregate, dict) or aggregate.get("status") not in OPEN:
        errors.append(f"{label}.aggregate.status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"digest_manifest", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_DIGEST_MANIFEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_DIGEST_MANIFEST_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
