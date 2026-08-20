#!/usr/bin/env python3
"""Validate v24 caption provenance-identity reconciliation evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_provenance_identity_reconciliation_authority_v24_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_provenance_reconciliation_authority_v23_evidence_v1"
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
DIGEST_AUTHORITY = {
    "digest_scope": "authority_and_generation",
    "digest_owner": "caption-presentation-service",
    "digest_algorithm": "sha256",
    "authority": "presentation_only",
    "binding_mode": "exact",
    "stale_policy": "reject_less_or_greater_generation",
}
PROVENANCE_AUTHORITY = {
    "provenance_scope": "authority_and_generation",
    "provenance_owner": "caption-presentation-service",
    "source_of_truth": "presentation_only",
    "lineage_mode": "exact",
    "digest_algorithm": "sha256",
    "stale_policy": "reject_less_or_greater_generation",
}
IDENTITY_AUTHORITY = {
    "identity_scope": "authority_and_generation",
    "identity_owner": "caption-presentation-service",
    "canonical_source": "caption-presentation-service",
    "identity_mode": "exact",
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


def validate_identity_authority(value: Any) -> list[str]:
    """Return identity contract violations without raising on malformed shapes."""

    if not isinstance(value, dict):
        return ["identity-authority record must be an object"]
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
        "identity_reconciled",
        "digest_verified",
        "stale_payload_mutation",
    ):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")

    if value.get("identity_authority") != IDENTITY_AUTHORITY:
        errors.append("identity_authority must exactly match canonical ownership and stale policy")
    if value.get("provenance_authority") != PROVENANCE_AUTHORITY:
        errors.append("provenance_authority must exactly match ownership, lineage, and stale policy")
    if value.get("digest_authority") != DIGEST_AUTHORITY:
        errors.append("digest_authority must exactly match digest ownership and stale policy")
    if value.get("binding") != BINDING:
        errors.append("binding must exactly match authority, generation owner, stale policy, and sha256")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")

    identity_digest = value.get("identity_digest")
    if identity_digest is not None and not _digest(identity_digest):
        errors.append("identity_digest must be null or a lowercase 64-character digest")
    if value.get("status") not in STATUSES:
        errors.append("status must remain planned, pending, or not_performed")
    if value.get("identity_owner") != "caption-presentation-service":
        errors.append("identity_owner must identify caption-presentation-service")
    if value.get("canonical_source") != "caption-presentation-service":
        errors.append("canonical_source must identify caption-presentation-service")
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
        return [f"identity-authority unreadable: {exc}"]
    return validate_identity_authority(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identity_authority", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.identity_authority)
    if errors:
        print("ACCESSIBILITY_CAPTION_PROVENANCE_IDENTITY_RECONCILIATION_AUTHORITY_V24_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_PROVENANCE_IDENTITY_RECONCILIATION_AUTHORITY_V24_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
