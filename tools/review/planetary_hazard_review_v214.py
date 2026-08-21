#!/usr/bin/env python3
"""Validate the v214 planetary-hazard review evidence boundary."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_review_v214"
VERSION = 214
OPEN = {"pending", "not_performed"}
KINDS = {"hazard", "landmark", "route"}
REQUIRED_EXCLUSIONS = {
    "visual_consistency_state_approval", "visual_review_consistency_approval",
    "native_render", "human_signoff",
}
FIXED = {
    "receipt_scope": "planetary_hazard_review", "evidence_phase": "review",
    "evidence_channel": "planetary-hazard", "review_owner": "review-ledger",
    "review_mode": "evidence_only", "authority_class": "non_runtime_review",
    "retention_policy": "review_scope_only", "closure_state": "open",
    "gate_policy": "native_human_open", "evidence_boundary": "pre_native_human",
    "evidence_surface": "review_manifest", "evidence_purpose": "consistency_audit",
    "evidence_class": "planetary_hazard", "evidence_contract": "planetary_hazard_review",
    "evidence_revision": "v214", "lineage_label": "root_receipt",
    "lineage_scope": "manifest_root", "lineage_root_kind": "manifest",
    "root_identity": "root_id", "root_identity_format": "id",
}
POLICIES = {
    "runtime_write_policy": "forbidden", "runtime_read_policy": "evidence_only",
    "runtime_process_policy": "forbidden", "runtime_network_policy": "forbidden",
    "runtime_environment_policy": "forbidden", "runtime_filesystem_policy": "forbidden",
    "runtime_time_policy": "forbidden", "runtime_random_policy": "forbidden",
    "runtime_thread_policy": "forbidden", "runtime_signal_policy": "forbidden",
    "runtime_mutex_policy": "forbidden", "runtime_ipc_policy": "forbidden",
    "runtime_subprocess_policy": "forbidden", "runtime_ui_policy": "forbidden",
    "runtime_audio_policy": "forbidden", "runtime_haptic_policy": "forbidden",
    "runtime_display_policy": "forbidden", "runtime_input_policy": "forbidden",
    "runtime_storage_policy": "forbidden", "runtime_cache_policy": "forbidden",
    "runtime_gpu_policy": "forbidden", "runtime_sensor_policy": "forbidden",
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _open_gate(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
    elif value.get("status") not in OPEN:
        errors.append(f"{label}.status must remain open")


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    """Return v214 violations without reading or changing runtime state."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    if value.get("schema_version") != VERSION:
        errors.append(f"{label}.schema_version must be {VERSION}")
    for key in ("world_id", "region_id", "manifest_id", "root_id", "review_id",
                "consistency_id", "state_id", "source_revision", "receipt_scope",
                "review_owner"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    expected = {**FIXED, **POLICIES}
    for key, wanted in expected.items():
        if value.get(key) != wanted:
            errors.append(f"{label}.{key} must be {wanted}")
    if value.get("root_identity_value") != value.get("root_id"):
        errors.append(f"{label}.root_identity_value must match root_id")
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
        for key, wanted in {**expected, "source_revision": value.get("source_revision")}.items():
            if receipt.get(key) != wanted:
                errors.append(f"{prefix}.{key} must match manifest")
        for key in ("lineage_anchor", "parent_id"):
            if receipt.get(key) != value.get("root_id"):
                errors.append(f"{prefix}.{key} must match manifest root_id")
        if receipt.get("root_identity_value") != value.get("root_identity_value"):
            errors.append(f"{prefix}.root_identity_value must match manifest")
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
    _open_gate(value.get("native_render"), f"{label}.native_render", errors)
    _open_gate(value.get("human_signoff"), f"{label}.human_signoff", errors)
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
        print("PLANETARY_HAZARD_REVIEW_V214_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_REVIEW_V214_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


























