#!/usr/bin/env python3
"""Validate v138 planetary-hazard review evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_review_v138"
VERSION = 138
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}
REQUIRED_EXCLUSIONS = {
    "visual_consistency_state_approval",
    "visual_review_consistency_approval",
    "native_render",
    "human_signoff",
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _gate(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
    elif value.get("status") not in OPEN:
        errors.append(f"{label}.status must remain open")


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    """Return bounded planetary-review violations without raising."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    if value.get("schema_version") != VERSION:
        errors.append(f"{label}.schema_version must be {VERSION}")
    for key in ("world_id", "region_id", "manifest_id", "root_id", "review_id", "consistency_id", "state_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("review_version") != VERSION:
        errors.append(f"{label}.review_version must be {VERSION}")
    pairs = value.get("pairs")
    if not isinstance(pairs, list) or len(pairs) != 3:
        errors.append(f"{label}.pairs must contain exactly three pairs")
        pairs = pairs if isinstance(pairs, list) else []
    ids: set[str] = set()
    evidence_ids: set[str] = set()
    kinds: set[str] = set()
    for index, pair in enumerate(pairs):
        prefix = f"{label}.pairs[{index}]"
        if not isinstance(pair, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = pair.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique and required")
        if _text(ident):
            ids.add(ident)
        kind = pair.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        elif isinstance(kind, str):
            kinds.add(kind)
        evidence_id = pair.get("review_evidence_id")
        if not _text(evidence_id) or evidence_id in evidence_ids:
            errors.append(f"{prefix}.review_evidence_id must be unique and required")
        if _text(evidence_id):
            evidence_ids.add(evidence_id)
        if pair.get("review_version") != VERSION:
            errors.append(f"{prefix}.review_version must be {VERSION}")
        if pair.get("parent_id") != value.get("root_id"):
            errors.append(f"{prefix}.parent_id must match manifest root_id")
        for key in ("review_id", "consistency_id", "state_id"):
            if pair.get(key) != value.get(key):
                errors.append(f"{prefix}.{key} must match manifest")
        if pair.get("schema") != SCHEMA or pair.get("schema_version") != VERSION:
            errors.append(f"{prefix}.schema and schema_version must match v{VERSION}")
        if pair.get("runtime_authority") is not False:
            errors.append(f"{prefix}.runtime_authority must be false")
        if pair.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.pairs must cover hazard, landmark, and route")
    _gate(value.get("native_render"), f"{label}.native_render", errors)
    _gate(value.get("human_signoff"), f"{label}.human_signoff", errors)
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not REQUIRED_EXCLUSIONS.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    return validate_manifest(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest)
    if errors:
        print("PLANETARY_HAZARD_REVIEW_V138_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_REVIEW_V138_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
