#!/usr/bin/env python3
"""Validate v34 versioned root/authority digest evidence for captions."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_versioned_root_authority_digest_v34_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_paired_root_authority_digest_v33_evidence_v1"
CONTRACT_VERSION = "v34"
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
VERSIONED_ROOT_AUTHORITY_DIGEST = {
    "contract_version": CONTRACT_VERSION,
    "root_scope": "authority_and_generation",
    "root_owner": "caption-presentation-service",
    "authority_projection": "exact",
    "root_source_of_truth": "presentation_only",
    "digest_scope": "authority_and_generation",
    "digest_owner": "caption-presentation-service",
    "digest_mode": "exact",
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


def validate_versioned_root_authority_digest(value: Any) -> list[str]:
    """Return versioned root/digest violations without raising on bad shapes."""

    if not isinstance(value, dict):
        return ["versioned root/authority digest record must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("source_schema") != SOURCE_SCHEMA:
        errors.append(f"source_schema must be {SOURCE_SCHEMA}")
    if value.get("contract_version") != CONTRACT_VERSION:
        errors.append(f"contract_version must be {CONTRACT_VERSION}")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    human_status = value.get("human_review_status")
    if not isinstance(human_status, str) or human_status not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("native_render_status") != "not_run":
        errors.append("native_render_status must remain not_run")
    for key in ("human_review_performed", "native_render_performed", "versioned_root_authority_digest_verified", "digest_verified", "stale_payload_mutation"):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")
    if value.get("versioned_root_authority_digest") != VERSIONED_ROOT_AUTHORITY_DIGEST:
        errors.append("versioned_root_authority_digest must exactly match v34 root, digest, and stale policy")
    if value.get("binding") != BINDING:
        errors.append("binding must exactly match authority, generation owner, stale policy, and sha256")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    for key in ("root_digest", "authority_digest"):
        digest = value.get(key)
        if digest is not None and not _digest(digest):
            errors.append(f"{key} must be null or a lowercase 64-character digest")
    if value.get("status") not in STATUSES:
        errors.append("status must remain planned, pending, or not_performed")
    for key in ("root_owner", "digest_owner", "generation_owner"):
        if value.get(key) != "caption-presentation-service":
            errors.append(f"{key} must identify caption-presentation-service")
    if value.get("authority_projection") != "exact":
        errors.append("authority_projection must remain exact")
    if value.get("root_source_of_truth") != "presentation_only":
        errors.append("root_source_of_truth must remain presentation_only")
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
        return [f"versioned root/authority digest unreadable: {exc}"]
    return validate_versioned_root_authority_digest(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("versioned_root_authority_digest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.versioned_root_authority_digest)
    if errors:
        print("ACCESSIBILITY_CAPTION_VERSIONED_ROOT_AUTHORITY_DIGEST_V34_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_VERSIONED_ROOT_AUTHORITY_DIGEST_V34_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
