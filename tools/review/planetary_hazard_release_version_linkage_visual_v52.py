#!/usr/bin/env python3
"""Validate v52 release/version linkage visual evidence."""
from __future__ import annotations
import argparse, json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_release_version_linkage_visual_v52"
VERSION = 52
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}

def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict): return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA: errors.append(f"{label}.schema must be {SCHEMA}")
    if value.get("schema_version") != VERSION: errors.append(f"{label}.schema_version must be {VERSION}")
    for key in ("world_id", "region_id", "manifest_id", "root_id", "release_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip(): errors.append(f"{label}.{key} is required")
    if value.get("release_version") != VERSION: errors.append(f"{label}.release_version must be 52")
    pairs = value.get("pairs")
    if not isinstance(pairs, list) or len(pairs) != 3:
        errors.append(f"{label}.pairs must contain exactly three pairs"); pairs = pairs if isinstance(pairs, list) else []
    ids: set[str] = set(); kinds: set[str] = set(); links: set[str] = set()
    for index, pair in enumerate(pairs):
        prefix = f"{label}.pairs[{index}]"
        if not isinstance(pair, dict): errors.append(f"{prefix} must be an object"); continue
        ident = pair.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids: errors.append(f"{prefix}.id must be unique")
        if isinstance(ident, str): ids.add(ident)
        kind = pair.get("kind")
        if kind not in KINDS: errors.append(f"{prefix}.kind is invalid")
        elif isinstance(kind, str): kinds.add(kind)
        link = pair.get("release_link_id")
        if not isinstance(link, str) or not link.strip() or link in links: errors.append(f"{prefix}.release_link_id must be unique and required")
        if isinstance(link, str): links.add(link)
        if pair.get("release_version") != VERSION: errors.append(f"{prefix}.release_version must be 52")
        if pair.get("schema") != SCHEMA or pair.get("schema_version") != VERSION: errors.append(f"{prefix}.schema and schema_version must match v52")
        if pair.get("parent_id") != value.get("root_id") or pair.get("release_id") != value.get("release_id"): errors.append(f"{prefix} release bindings must match manifest")
        if pair.get("runtime_authority") is not False: errors.append(f"{prefix}.runtime_authority must be false")
        if pair.get("status") not in OPEN: errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS: errors.append(f"{label}.pairs must cover hazard, landmark, and route")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN: errors.append(f"{label}.{key}.status must remain open")
    required = {"release_linkage_visual_approval", "native_render", "human_signoff"}
    if not isinstance(value.get("claims_excluded"), list) or not required.issubset(set(value["claims_excluded"])): errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("manifest", type=Path); args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors: print("PLANETARY_RELEASE_LINKAGE_V52_INVALID"); print("\n".join(f"- {e}" for e in errors)); return 1
    print("PLANETARY_RELEASE_LINKAGE_V52_VALID_OPEN"); return 0
if __name__ == "__main__": raise SystemExit(main())
