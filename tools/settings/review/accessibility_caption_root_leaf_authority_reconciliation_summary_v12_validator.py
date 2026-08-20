#!/usr/bin/env python3
"""Validate v12 root/leaf authority reconciliation for caption lineage."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_root_leaf_authority_reconciliation_summary_v12_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_stale_authority_generation_summary_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")
LEAVES = ("contract", "service", "summary")
ROOT_AUTHORITY = "presentation_only"
LEAF_AUTHORITY = {"contract": "presentation_only", "service": "presentation_only", "summary": "review_index_only"}
GENERATION = {"owner": "caption-presentation-service", "stale_policy": "reject_less_or_greater_generation", "reset_step": 1}
AUTHORITY = {"presentation_only": True, "audio_authority": False, "audio_playback": False, "caption_queue_authority": False, "settings_authority": False, "gameplay_authority": False, "network_authority": False}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _references(value: Any, errors: list[str]) -> None:
    if value is None:
        return
    if not isinstance(value, list) or not value:
        errors.append("evidence must be null or a non-empty evidence list")
        return
    for index, item in enumerate(value):
        prefix = f"evidence[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if not isinstance(item.get("kind"), str) or item.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{prefix}.kind must be log, video, image, or report")
        if not _text(item.get("path")):
            errors.append(f"{prefix}.path must be non-empty text")
        if not _digest(item.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")


def _validate_leaves(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["leaves must contain exactly three ordered authority leaves"]
    if len(value) != len(LEAVES):
        errors.append("leaves must contain exactly three ordered authority leaves")
    ids: list[str] = []
    for index, leaf in enumerate(value):
        prefix = f"leaves[{index}]"
        if not isinstance(leaf, dict):
            errors.append(f"{prefix} must be an object")
            continue
        leaf_id = leaf.get("id")
        if leaf_id not in LEAVES:
            errors.append(f"{prefix}.id must be contract, service, or summary")
        else:
            ids.append(leaf_id)
            if leaf.get("authority") != LEAF_AUTHORITY[leaf_id]:
                errors.append(f"{prefix}.authority must match its authority leaf")
        if not _text(leaf.get("source")):
            errors.append(f"{prefix}.source must be non-empty text")
        if not _text(leaf.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
    if len(ids) != len(set(ids)):
        errors.append("leaves.id values must be unique")
    if tuple(ids) != LEAVES:
        errors.append("leaves must exactly match contract, service, summary order")
    return errors


def validate_summary(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("source_schema") != SOURCE_SCHEMA:
        errors.append(f"source_schema must be {SOURCE_SCHEMA}")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    human_status = value.get("human_review_status")
    if not isinstance(human_status, str) or human_status not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("native_render_status") != "not_run":
        errors.append("native_render_status must remain not_run")
    for key, expected in (("human_review_performed", False), ("native_render_performed", False), ("digest_verified", False), ("stale_payload_mutation", False)):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("digest_algorithm") != "sha256":
        errors.append("digest_algorithm must be sha256")
    if value.get("canonicalization") != "utf8_json_sorted_keys_no_whitespace_v12":
        errors.append("canonicalization must be utf8_json_sorted_keys_no_whitespace_v12")
    if value.get("status") not in {"planned", "pending", "not_performed"}:
        errors.append("status must remain planned, pending, or not_performed")
    if not _digest(value.get("digest")):
        errors.append("digest must be a lowercase 64-character digest")
    if value.get("root_authority") != ROOT_AUTHORITY:
        errors.append("root_authority must be presentation_only")
    if value.get("root_generation") != GENERATION:
        errors.append("root_generation must exactly match the stale-generation policy")
    if value.get("reconciliation_policy") != "root_must_match_each_leaf":
        errors.append("reconciliation_policy must be root_must_match_each_leaf")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("contract_id") != "caption-accessibility-contract":
        errors.append("contract_id must identify caption-accessibility-contract")
    errors.extend(_validate_leaves(value.get("leaves")))
    _references(value.get("evidence"), errors)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"summary unreadable: {exc}"]
    return validate_summary(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.summary)
    if errors:
        print("ACCESSIBILITY_CAPTION_ROOT_LEAF_AUTHORITY_V12_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_ROOT_LEAF_AUTHORITY_V12_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
