#!/usr/bin/env python3
"""Validate review metadata for a planetary hazard visual digest manifest."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_digest_manifest_review_v1"
OPEN = {"pending", "not_performed"}
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision", "reviewer_role"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    records = value.get("records")
    if not isinstance(records, list) or not records:
        errors.append(f"{label}.records must contain review records")
        records = []
    ids: set[str] = set()
    for index, record in enumerate(records):
        prefix = f"{label}.records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = record.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        if not isinstance(record.get("sha256"), str) or not SHA256.fullmatch(record["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if not _text(record.get("question")) or not _text(record.get("answer_space")):
            errors.append(f"{prefix} requires question and answer_space")
        if record.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    summary = value.get("review_summary")
    if not isinstance(summary, dict) or summary.get("status") not in OPEN:
        errors.append(f"{label}.review_summary.status must remain open")
    for key in ("native_render", "human_signoff"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"review_approval", "native_render", "human_signoff"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_DIGEST_MANIFEST_REVIEW_VALIDATOR_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_DIGEST_MANIFEST_REVIEW_VALIDATOR_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
