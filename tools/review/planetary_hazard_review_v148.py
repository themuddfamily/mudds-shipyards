#!/usr/bin/env python3
"""Validate v148 planetary-hazard non-runtime review authority receipts."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_review_v148"
VERSION = 148
PHASE = "review"
CHANNEL = "planetary-hazard"
OWNER = "review-ledger"
MODE = "evidence_only"
AUTHORITY = "non_runtime_review"
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
    """Return bounded authority/receipt violations without raising."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    if value.get("schema_version") != VERSION:
        errors.append(f"{label}.schema_version must be {VERSION}")
    for key in (
        "world_id", "region_id", "manifest_id", "root_id", "review_id",
        "consistency_id", "state_id", "source_revision", "receipt_scope",
        "review_owner",
    ):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("receipt_scope") != "planetary_hazard_review":
        errors.append(f"{label}.receipt_scope is invalid")
    if value.get("evidence_phase") != PHASE:
        errors.append(f"{label}.evidence_phase must be {PHASE}")
    if value.get("evidence_channel") != CHANNEL:
        errors.append(f"{label}.evidence_channel must be {CHANNEL}")
    if value.get("review_owner") != OWNER:
        errors.append(f"{label}.review_owner must be {OWNER}")
    if value.get("review_mode") != MODE:
        errors.append(f"{label}.review_mode must be {MODE}")
    if value.get("authority_class") != AUTHORITY:
        errors.append(f"{label}.authority_class must be {AUTHORITY}")
    if value.get("review_version") != VERSION:
        errors.append(f"{label}.review_version must be {VERSION}")

    receipts = value.get("receipts")
    if not isinstance(receipts, list) or len(receipts) != 3:
        errors.append(f"{label}.receipts must contain exactly three receipts")
        receipts = receipts if isinstance(receipts, list) else []
    receipt_ids: set[str] = set()
    evidence_ids: set[str] = set()
    kinds: set[str] = set()
    for index, receipt in enumerate(receipts):
        prefix = f"{label}.receipts[{index}]"
        if not isinstance(receipt, dict):
            errors.append(f"{prefix} must be an object")
            continue
        receipt_id = receipt.get("receipt_id")
        if not _text(receipt_id) or receipt_id in receipt_ids:
            errors.append(f"{prefix}.receipt_id must be unique and required")
        if _text(receipt_id):
            receipt_ids.add(receipt_id)
        evidence_id = receipt.get("review_evidence_id")
        if not _text(evidence_id) or evidence_id in evidence_ids:
            errors.append(f"{prefix}.review_evidence_id must be unique and required")
        if _text(evidence_id):
            evidence_ids.add(evidence_id)
        kind = receipt.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        elif isinstance(kind, str):
            kinds.add(kind)
        if receipt.get("review_version") != VERSION:
            errors.append(f"{prefix}.review_version must be {VERSION}")
        for key in (
            "evidence_phase", "evidence_channel", "review_owner", "review_mode",
            "authority_class", "receipt_scope", "source_revision",
        ):
            if receipt.get(key) != value.get(key):
                errors.append(f"{prefix}.{key} must match manifest")
        if receipt.get("parent_id") != value.get("root_id"):
            errors.append(f"{prefix}.parent_id must match manifest root_id")
        for key in ("review_id", "consistency_id", "state_id"):
            if receipt.get(key) != value.get(key):
                errors.append(f"{prefix}.{key} must match manifest")
        if receipt.get("schema") != SCHEMA or receipt.get("schema_version") != VERSION:
            errors.append(f"{prefix}.schema and schema_version must match v{VERSION}")
        if receipt.get("runtime_authority") is not False:
            errors.append(f"{prefix}.runtime_authority must be false")
        if receipt.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if kinds != KINDS:
        errors.append(f"{label}.receipts must cover hazard, landmark, and route")
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
        print("PLANETARY_HAZARD_REVIEW_V148_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_REVIEW_V148_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
