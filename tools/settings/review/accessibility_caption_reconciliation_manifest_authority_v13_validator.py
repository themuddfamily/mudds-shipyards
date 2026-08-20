#!/usr/bin/env python3
"""Validate v13 authority manifest reconciliation for caption fallback."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_reconciliation_manifest_authority_v13_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_stale_authority_generation_summary_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")
MANIFEST_IDS = ("contract", "service", "summary")
MANIFEST_RULES = {
    "contract": {"source": "scripts/ui/caption_accessibility_contract.gd", "authority": "presentation_only", "generation_scope": "observes_service_generation", "stale_policy": "reject_less_or_greater_generation"},
    "service": {"source": "scripts/ui/caption_presentation_service.gd", "authority": "presentation_only", "generation_scope": "owns_generation", "stale_policy": "reset_invalidates_old_payload"},
    "summary": {"source": "reports/caption-reconciliation-manifest-v13.json", "authority": "review_index_only", "generation_scope": "records_service_generation", "stale_policy": "does_not_mutate_runtime"},
}
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
        kind = item.get("kind")
        if not isinstance(kind, str) or kind not in EVIDENCE_KINDS:
            errors.append(f"{prefix}.kind must be log, video, image, or report")
        if not _text(item.get("path")):
            errors.append(f"{prefix}.path must be non-empty text")
        if not _digest(item.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")


def _validate_manifest(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["manifest must contain exactly three ordered authority entries"]
    if len(value) != len(MANIFEST_IDS):
        errors.append("manifest must contain exactly three ordered authority entries")
    ids: list[str] = []
    for index, entry in enumerate(value):
        prefix = f"manifest[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entry_id = entry.get("id")
        if entry_id not in MANIFEST_IDS:
            errors.append(f"{prefix}.id must be contract, service, or summary")
        else:
            ids.append(entry_id)
            expected = MANIFEST_RULES[entry_id]
            for key in ("source", "authority", "generation_scope", "stale_policy"):
                if entry.get(key) != expected[key]:
                    errors.append(f"{prefix}.{key} must match its authority manifest rule")
        if not _text(entry.get("expected_behavior")):
            errors.append(f"{prefix}.expected_behavior must be non-empty text")
    if len(ids) != len(set(ids)):
        errors.append("manifest.id values must be unique")
    if tuple(ids) != MANIFEST_IDS:
        errors.append("manifest must exactly match contract, service, summary order")
    return errors


def validate_manifest(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["manifest record must be an object"]
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
    if value.get("canonicalization") != "utf8_json_sorted_keys_no_whitespace_v13":
        errors.append("canonicalization must be utf8_json_sorted_keys_no_whitespace_v13")
    if value.get("status") not in {"planned", "pending", "not_performed"}:
        errors.append("status must remain planned, pending, or not_performed")
    if not _digest(value.get("digest")):
        errors.append("digest must be a lowercase 64-character digest")
    if value.get("generation_owner") != "caption-presentation-service":
        errors.append("generation_owner must be caption-presentation-service")
    if value.get("global_stale_policy") != "reject_less_or_greater_generation":
        errors.append("global_stale_policy must reject_less_or_greater_generation")
    if value.get("manifest_authority") != "root_reconciles_all_entries":
        errors.append("manifest_authority must be root_reconciles_all_entries")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    errors.extend(_validate_manifest(value.get("manifest")))
    _references(value.get("evidence"), errors)
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
        print("ACCESSIBILITY_CAPTION_RECONCILIATION_MANIFEST_V13_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_RECONCILIATION_MANIFEST_V13_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
