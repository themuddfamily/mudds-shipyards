#!/usr/bin/env python3
"""Validate v97 accessibility-caption verification/state evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_verification_state_v97_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_attestation_lineage_v96_evidence_v1"
SCHEMA_VERSION = "v97"
PREVIOUS_VERSION = "v96"
SOURCE_ID = "caption-presentation-service"
SOURCE_ATTESTATION_ID = "caption-accessibility-attestation-v96"
VERIFICATION_ID = "caption-accessibility-verification-v97"
CONTRACT_ID = "caption-accessibility-contract"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
STATUSES = {"planned", "pending", "not_performed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")
BINDING = {
    "verification_scope": "attestation_to_state",
    "source_id": SOURCE_ID,
    "source_schema": SOURCE_SCHEMA,
    "source_version": PREVIOUS_VERSION,
    "source_attestation_id": SOURCE_ATTESTATION_ID,
    "authority": "presentation_only",
    "generation_owner": SOURCE_ID,
    "stale_policy": "reject_less_or_greater_generation",
    "human_gate": "open",
    "native_policy": "not_run",
    "algorithm": "sha256",
}
VERIFICATION_STATE = {
    "verification_id": VERIFICATION_ID,
    "verification_status": "unverified",
    "state_status": "open",
    "state_mode": "exact",
    "source_id": SOURCE_ID,
    "source_mode": "exact",
    "source_attestation_id": SOURCE_ATTESTATION_ID,
    "source_attestation_status": "unverified",
    "contract_id": CONTRACT_ID,
    "contract_mode": "exact",
    "current_version": SCHEMA_VERSION,
    "previous_version": PREVIOUS_VERSION,
    "version_relation": "adjacent_exact",
    "authority_scope": "authority_and_generation",
    "authority_owner": SOURCE_ID,
    "provenance_source_of_truth": "presentation_only",
    "authority": "presentation_only",
    "generation_owner": SOURCE_ID,
    "stale_policy": "reject_less_or_greater_generation",
    "human_gate": "open",
    "native_status": "not_run",
}
VERIFICATION_CHECKS = {
    "source_chain": True,
    "source_identity": True,
    "source_attestation_unverified": True,
    "verification_owner": True,
    "authority_scope": True,
    "generation_owner": True,
    "stale_policy": True,
    "human_gate": True,
    "native_boundary": True,
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


def validate_verification_state(value: Any) -> list[str]:
    """Return verification/state violations without raising."""
    if not isinstance(value, dict):
        return ["verification/state record must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("source_schema") != SOURCE_SCHEMA:
        errors.append(f"source_schema must be {SOURCE_SCHEMA}")
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    status = value.get("human_review_status")
    if not isinstance(status, str) or status not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("native_render_status") != "not_run":
        errors.append("native_render_status must remain not_run")
    for key in ("human_review_performed", "native_render_performed", "verification_claimed", "state_claimed", "verification_verified", "stale_payload_mutation"):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")
    if value.get("binding") != BINDING:
        errors.append("binding must exactly match v96 source, authority, stale, human, and native policy")
    if value.get("verification_state") != VERIFICATION_STATE:
        errors.append("verification_state must exactly match v97 verification, source, and open-gate policy")
    if value.get("verification_checks") != VERIFICATION_CHECKS:
        errors.append("verification_checks must exactly match the bounded v97 checks")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    expected_fields = (
        ("verification_id", VERIFICATION_ID),
        ("verification_status", "unverified"),
        ("state_status", "open"),
        ("state_mode", "exact"),
        ("source_id", SOURCE_ID),
        ("source_mode", "exact"),
        ("source_attestation_id", SOURCE_ATTESTATION_ID),
        ("source_attestation_status", "unverified"),
        ("contract_id", CONTRACT_ID),
        ("contract_mode", "exact"),
        ("current_version", SCHEMA_VERSION),
        ("previous_version", PREVIOUS_VERSION),
        ("version_relation", "adjacent_exact"),
        ("provenance_source_of_truth", "presentation_only"),
    )
    for key, expected in expected_fields:
        if value.get(key) != expected:
            errors.append(f"{key} must be {expected}")
    if value.get("status") not in STATUSES:
        errors.append("status must remain planned, pending, or not_performed")
    for key in ("authority_owner", "generation_owner"):
        if value.get(key) != SOURCE_ID:
            errors.append(f"{key} must identify {SOURCE_ID}")
    if value.get("service_id") != SOURCE_ID:
        errors.append(f"service_id must identify {SOURCE_ID}")
    if value.get("contract_id") != CONTRACT_ID:
        errors.append(f"contract_id must identify {CONTRACT_ID}")
    _evidence(value.get("evidence"), errors)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"verification/state unreadable: {exc}"]
    return validate_verification_state(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("verification_state", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.verification_state)
    if errors:
        print("ACCESSIBILITY_CAPTION_VERIFICATION_STATE_V97_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_VERIFICATION_STATE_V97_READY: verification remains unverified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
