#!/usr/bin/env python3
"""Validate v18 digest completeness authority metadata for caption manifests."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_manifest_digest_completeness_authority_v18_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_stale_authority_generation_summary_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_INPUTS = ("source_schema", "source_revision", "manifest", "generation", "authority")
COMPLETENESS = {"required_count": 5, "provided_count": 5, "missing_count": 0, "complete": True}
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


def validate_manifest(value: Any) -> list[str]:
    if not isinstance(value, dict):
        return ["manifest must be an object"]
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
    for key, expected in (("human_review_performed", False), ("native_render_performed", False), ("digest_verified", False), ("digest_generated", False), ("stale_payload_mutation", False)):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("digest_algorithm") != "sha256":
        errors.append("digest_algorithm must be sha256")
    if value.get("canonicalization") != "utf8_json_sorted_keys_no_whitespace_v18":
        errors.append("canonicalization must be utf8_json_sorted_keys_no_whitespace_v18")
    if value.get("digest_scope") != "manifest_digest_completeness_authority":
        errors.append("digest_scope must be manifest_digest_completeness_authority")
    if value.get("status") not in {"planned", "pending", "not_performed"}:
        errors.append("status must remain planned, pending, or not_performed")
    if not _digest(value.get("digest")):
        errors.append("digest must be a lowercase 64-character digest")
    if value.get("required_inputs") != list(REQUIRED_INPUTS):
        errors.append("required_inputs must exactly match source schema, revision, manifest, generation, authority")
    if value.get("completeness") != COMPLETENESS:
        errors.append("completeness must exactly match five provided inputs and zero missing")
    if value.get("generation_policy") != "monotonic_reset_increment":
        errors.append("generation_policy must be monotonic_reset_increment")
    if value.get("stale_policy") != "reject_less_or_greater_generation":
        errors.append("stale_policy must reject_less_or_greater_generation")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
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
        print("ACCESSIBILITY_CAPTION_MANIFEST_DIGEST_COMPLETENESS_V18_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_MANIFEST_DIGEST_COMPLETENESS_V18_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
