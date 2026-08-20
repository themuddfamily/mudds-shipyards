#!/usr/bin/env python3
"""Validate v10 provenance lineage summaries for caption accessibility."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_provenance_lineage_summary_v10_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_stale_authority_generation_summary_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")
LINEAGE_STAGES = ("contract", "service", "summary")
LINEAGE_RULES = {
    "contract": {"source": "scripts/ui/caption_accessibility_contract.gd", "parent": None, "authority": "presentation_only"},
    "service": {"source": "scripts/ui/caption_presentation_service.gd", "parent": "contract", "authority": "presentation_only"},
    "summary": {"source": "reports/caption-provenance-lineage-v10.json", "parent": "service", "authority": "review_index_only"},
}
AUTHORITY = {"presentation_only": True, "audio_authority": False, "audio_playback": False, "caption_queue_authority": False, "settings_authority": False, "gameplay_authority": False, "network_authority": False}
GENERATION = {"owner": "caption-presentation-service", "stale_policy": "reject_less_or_greater_generation", "reset_step": 1}


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


def _validate_lineage(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["lineage must contain exactly three ordered provenance stages"]
    if len(value) != len(LINEAGE_STAGES):
        errors.append("lineage must contain exactly three ordered provenance stages")
    stages: list[str] = []
    for index, row in enumerate(value):
        prefix = f"lineage[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        stage = row.get("stage")
        if stage not in LINEAGE_STAGES:
            errors.append(f"{prefix}.stage must be contract, service, or summary")
        else:
            stages.append(stage)
            expected = LINEAGE_RULES[stage]
            for key in ("source", "parent", "authority"):
                if row.get(key) != expected[key]:
                    errors.append(f"{prefix}.{key} must match its provenance stage")
        if not _text(row.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
    if len(stages) != len(set(stages)):
        errors.append("lineage.stage values must be unique")
    if tuple(stages) != LINEAGE_STAGES:
        errors.append("lineage must exactly match contract, service, summary order")
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
    if value.get("canonicalization") != "utf8_json_sorted_keys_no_whitespace_v10":
        errors.append("canonicalization must be utf8_json_sorted_keys_no_whitespace_v10")
    if value.get("status") not in {"planned", "pending", "not_performed"}:
        errors.append("status must remain planned, pending, or not_performed")
    if not _digest(value.get("digest")):
        errors.append("digest must be a lowercase 64-character digest")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("contract_id") != "caption-accessibility-contract":
        errors.append("contract_id must identify caption-accessibility-contract")
    if value.get("generation") != GENERATION:
        errors.append("generation must exactly match the stale-generation policy")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    errors.extend(_validate_lineage(value.get("lineage")))
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
        print("ACCESSIBILITY_CAPTION_PROVENANCE_LINEAGE_V10_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_PROVENANCE_LINEAGE_V10_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
