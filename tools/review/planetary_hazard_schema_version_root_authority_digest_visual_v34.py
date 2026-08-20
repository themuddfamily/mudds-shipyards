#!/usr/bin/env python3
"""Validate the v34 planetary hazard visual root/authority digest contract."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_schema_version_root_authority_digest_visual_v34"
VERSION = 34
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    if value.get("schema_version") != VERSION:
        errors.append(f"{label}.schema_version must be {VERSION}")
    for key in ("world_id", "region_id", "manifest_id", "root_id", "authority_id", "source_revision"):
        if not isinstance(value.get(key), str) or not value[key].strip():
            errors.append(f"{label}.{key} is required")
    pairs = value.get("pairs")
    if not isinstance(pairs, list) or len(pairs) != 3:
        errors.append(f"{label}.pairs must contain exactly three pairs")
        pairs = pairs if isinstance(pairs, list) else []
    ids: set[str] = set()
    kinds: set[str] = set()
    for index, pair in enumerate(pairs):
        prefix = f"{label}.pairs[{index}]"
        if not isinstance(pair, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = pair.get("id")
        if not isinstance(ident, str) or not ident.strip() or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        if isinstance(ident, str):
            ids.add(ident)
        kind = pair.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        elif isinstance(kind, str):
            kinds.add(kind)
        if pair.get("parent_id") != value.get("root_id") or pair.get("authority_id") != value.get("authority_id"):
            errors.append(f"{prefix}.parent_id and authority_id must match manifest")
        if pair.get("schema") != SCHEMA or pair.get("schema_version") != VERSION:
            errors.append(f"{prefix}.schema and schema_version must match v34")
        for key in ("source_sha256", "review_sha256"):
            if not isinstance(pair.get(key), str) or not HEX64.fullmatch(pair[key]):
                errors.append(f"{prefix}.{key} must be a 64-character digest")
        if pair.get("runtime_authority") is not False:
            errors.append(f"{prefix}.runtime_authority must be false")
        if pair.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.pairs must cover hazard, landmark, and route")
    aggregate = value.get("authority_digest")
    if not isinstance(aggregate, dict) or aggregate.get("schema") != SCHEMA or aggregate.get("schema_version") != VERSION or aggregate.get("algorithm") != "sha256" or not isinstance(aggregate.get("value"), str) or not HEX64.fullmatch(aggregate["value"]):
        errors.append(f"{label}.authority_digest must be v34 sha256 with a 64-character value")
    elif aggregate.get("status") not in OPEN:
        errors.append(f"{label}.authority_digest.status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    required = {"schema_authority_approval", "native_render", "human_signoff"}
    if not isinstance(exclusions, list) or not required.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_SCHEMA_VERSION_AUTHORITY_V34_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SCHEMA_VERSION_AUTHORITY_V34_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
