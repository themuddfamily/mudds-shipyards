#!/usr/bin/env python3
"""Validate v29 paired-digest lineage authority evidence for captions."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_paired_digest_lineage_authority_v29_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_paired_digest_reconciliation_authority_v28_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
STATUSES = {"planned", "pending", "not_performed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")

BINDING = {
    "digest_scope": "authority_and_generation",
    "authority": "presentation_only",
    "generation_owner": "caption-presentation-service",
    "stale_policy": "reject_less_or_greater_generation",
    "algorithm": "sha256",
}
PAIRED_DIGEST_LINEAGE = {
    "lineage_scope": "authority_and_generation",
    "primary_owner": "caption-presentation-service",
    "secondary_owner": "caption-presentation-service",
    "lineage_mode": "exact",
    "source_of_truth": "presentation_only",
    "generation_owner": "caption-presentation-service",
    "digest_algorithm": "sha256",
    "stale_policy": "reject_less_or_greater_generation",
}
AUTHORITY = {
    "presentation_only": True,
    "audio_authority": False,
    "audio_playback": False,
    "caption_queue_authority": False,
    "settings_authority": False,
    "gameplay_authority": False,
    "network_authority": False,
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _evidence(value: Any, errors: list[str]) -> None:
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


def validate_paired_digest_lineage(value: Any) -> list[str]:
    """Return lineage contract violations without raising on malformed shapes."""

    if not isinstance(value, dict):
        return ["paired-digest lineage record must be an object"]
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
    for key in (
        "human_review_performed",
        "native_render_performed",
        "paired_digest_lineage_verified",
        "digest_verified",
        "stale_payload_mutation",
    ):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")

    if value.get("paired_digest_lineage") != PAIRED_DIGEST_LINEAGE:
        errors.append("paired_digest_lineage must exactly match lineage ownership and stale policy")
    if value.get("binding") != BINDING:
        errors.append("binding must exactly match authority, generation owner, stale policy, and sha256")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")

    for key in ("primary_digest", "secondary_digest"):
        digest = value.get(key)
        if digest is not None and not _digest(digest):
            errors.append(f"{key} must be null or a lowercase 64-character digest")
    if value.get("status") not in STATUSES:
        errors.append("status must remain planned, pending, or not_performed")
    for key in ("primary_owner", "secondary_owner", "generation_owner"):
        if value.get(key) != "caption-presentation-service":
            errors.append(f"{key} must identify caption-presentation-service")
    if value.get("source_of_truth") != "presentation_only":
        errors.append("source_of_truth must remain presentation_only")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("contract_id") != "caption-accessibility-contract":
        errors.append("contract_id must identify caption-accessibility-contract")
    _evidence(value.get("evidence"), errors)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"paired-digest lineage unreadable: {exc}"]
    return validate_paired_digest_lineage(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paired_digest_lineage", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.paired_digest_lineage)
    if errors:
        print("ACCESSIBILITY_CAPTION_PAIRED_DIGEST_LINEAGE_AUTHORITY_V29_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_PAIRED_DIGEST_LINEAGE_AUTHORITY_V29_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
