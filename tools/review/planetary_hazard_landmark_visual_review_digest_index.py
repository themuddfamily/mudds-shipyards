#!/usr/bin/env python3
"""Validate an index of planetary hazard landmark visual review digests."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_review_digest_index_v1"
OPEN = {"pending", "not_performed"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_index(value: Any, label: str = "index") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    digests = value.get("digests")
    if not isinstance(digests, list) or not digests:
        errors.append(f"{label}.digests must contain review digests")
        digests = []
    ids: set[str] = set()
    for index, digest in enumerate(digests):
        prefix = f"{label}.digests[{index}]"
        if not isinstance(digest, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = digest.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if digest.get("kind") not in {"hazard", "landmark", "route"}:
            errors.append(f"{prefix}.kind is invalid")
        if not isinstance(digest.get("sha256"), str) or not HEX64.fullmatch(digest["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if not _text(digest.get("source_path")) or not digest["source_path"].startswith("res://"):
            errors.append(f"{prefix}.source_path must be a res:// path")
        if digest.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
        if not _text(digest.get("review_question")):
            errors.append(f"{prefix}.review_question is required")
    aggregate = value.get("aggregate")
    if not isinstance(aggregate, dict) or not isinstance(aggregate.get("sha256"), str) or not HEX64.fullmatch(aggregate["sha256"]):
        errors.append(f"{label}.aggregate.sha256 must be a 64-character digest")
    elif aggregate.get("status") not in OPEN:
        errors.append(f"{label}.aggregate.status must remain open")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"digest_index", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("index", type=Path)
    args = parser.parse_args(argv)
    errors = validate_index(json.loads(args.index.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_DIGEST_INDEX_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_DIGEST_INDEX_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
