#!/usr/bin/env python3
"""Validate v174 planetary-hazard review runtime signal boundaries."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_review_v174"
VERSION = 174
PHASE = "review"
CHANNEL = "planetary-hazard"
OWNER = "review-ledger"
MODE = "evidence_only"
AUTHORITY = "non_runtime_review"
RETENTION = "review_scope_only"
CLOSURE = "open"
GATE_POLICY = "native_human_open"
BOUNDARY = "pre_native_human"
SURFACE = "review_manifest"
PURPOSE = "consistency_audit"
EVIDENCE_CLASS = "planetary_hazard"
CONTRACT = "planetary_hazard_review"
EVIDENCE_REVISION = "v174"
LINEAGE = "root_receipt"
LINEAGE_SCOPE = "manifest_root"
ROOT_KIND = "manifest"
ROOT_IDENTITY = "root_id"
ROOT_FORMAT = "id"
WRITE_POLICY = "forbidden"
READ_POLICY = "evidence_only"
PROCESS_POLICY = "forbidden"
NETWORK_POLICY = "forbidden"
ENV_POLICY = "forbidden"
FILESYSTEM_POLICY = "forbidden"
TIME_POLICY = "forbidden"
RANDOM_POLICY = "forbidden"
THREAD_POLICY = "forbidden"
SIGNAL_POLICY = "forbidden"
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
    """Return bounded signal-policy/receipt violations without raising."""
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
    expected = {
        "receipt_scope": "planetary_hazard_review", "evidence_phase": PHASE,
        "evidence_channel": CHANNEL, "review_owner": OWNER, "review_mode": MODE,
        "authority_class": AUTHORITY, "retention_policy": RETENTION,
        "closure_state": CLOSURE, "gate_policy": GATE_POLICY,
        "evidence_boundary": BOUNDARY, "evidence_surface": SURFACE,
        "evidence_purpose": PURPOSE, "evidence_class": EVIDENCE_CLASS,
        "evidence_contract": CONTRACT, "evidence_revision": EVIDENCE_REVISION,
        "lineage_label": LINEAGE, "lineage_scope": LINEAGE_SCOPE,
        "lineage_root_kind": ROOT_KIND, "root_identity": ROOT_IDENTITY,
        "root_identity_format": ROOT_FORMAT, "runtime_write_policy": WRITE_POLICY,
        "runtime_read_policy": READ_POLICY, "runtime_process_policy": PROCESS_POLICY,
        "runtime_network_policy": NETWORK_POLICY, "runtime_environment_policy": ENV_POLICY,
        "runtime_filesystem_policy": FILESYSTEM_POLICY, "runtime_time_policy": TIME_POLICY,
        "runtime_random_policy": RANDOM_POLICY, "runtime_thread_policy": THREAD_POLICY,
        "runtime_signal_policy": SIGNAL_POLICY,
    }
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
        for key in (*expected, "source_revision"):
            if receipt.get(key) != value.get(key):
                errors.append(f"{prefix}.{key} must match manifest")
        if receipt.get("lineage_anchor") != value.get("root_id"):
            errors.append(f"{prefix}.lineage_anchor must match manifest root_id")
        if receipt.get("root_identity_value") != value.get("root_identity_value"):
            errors.append(f"{prefix}.root_identity_value must match manifest")
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
        print("PLANETARY_HAZARD_REVIEW_V174_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_REVIEW_V174_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
