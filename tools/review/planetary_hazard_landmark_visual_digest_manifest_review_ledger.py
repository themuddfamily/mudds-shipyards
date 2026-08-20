#!/usr/bin/env python3
"""Validate human-review metadata for a planetary visual digest manifest."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_digest_manifest_review_v1"
OPEN = {"pending", "not_performed"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision", "reviewer_role"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must contain manifest review entries")
        entries = []
    ids: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = entry.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if not isinstance(entry.get("sha256"), str) or not HEX64.fullmatch(entry["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if not _text(entry.get("review_question")) or not _text(entry.get("reviewer_note")):
            errors.append(f"{prefix} requires review_question and reviewer_note")
        if entry.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    aggregate = value.get("aggregate_review")
    if not isinstance(aggregate, dict) or aggregate.get("status") not in OPEN:
        errors.append(f"{label}.aggregate_review.status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"manifest_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_DIGEST_MANIFEST_REVIEW_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_DIGEST_MANIFEST_REVIEW_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
