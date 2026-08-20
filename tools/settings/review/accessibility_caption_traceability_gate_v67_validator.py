#!/usr/bin/env python3
"""Validate v67 accessibility-caption traceability/gate evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_traceability_gate_v67_evidence_v1"
SOURCE_SCHEMA = "accessibility_caption_readiness_consistency_v66_evidence_v1"
SCHEMA_VERSION = "v67"
PREVIOUS_VERSION = "v66"
SOURCE_ID = "caption-presentation-service"
SOURCE_READINESS_ID = "caption-accessibility-readiness-v66"
TRACEABILITY_ID = "caption-accessibility-traceability-v67"
CONTRACT_ID = "caption-accessibility-contract"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
STATUSES = {"planned", "pending", "not_performed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")
GATE = {
    "traceability_scope": "source_to_gate",
    "source_id": SOURCE_ID,
    "source_schema": SOURCE_SCHEMA,
    "source_version": PREVIOUS_VERSION,
    "source_readiness_id": SOURCE_READINESS_ID,
    "authority": "presentation_only",
    "generation_owner": SOURCE_ID,
    "stale_policy": "reject_less_or_greater_generation",
    "human_gate": "open",
    "native_policy": "not_run",
    "algorithm": "sha256",
}
TRACEABILITY = {
    "traceability_id": TRACEABILITY_ID,
    "gate_status": "open",
    "traceability_mode": "exact",
    "source_id": SOURCE_ID,
    "source_mode": "exact",
    "source_readiness_id": SOURCE_READINESS_ID,
    "source_readiness_status": "open",
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
TRACEABILITY_CHECKS = {
    "source_chain": True,
    "source_identity": True,
    "source_readiness_open": True,
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


def validate_traceability_gate(value: Any) -> list[str]:
    """Return traceability/gate violations without raising."""
    if not isinstance(value, dict):
        return ["traceability/gate record must be an object"]
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
    for key in ("human_review_performed", "native_render_performed", "traceability_verified", "gate_closed", "stale_payload_mutation"):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")
    if value.get("gate") != GATE:
        errors.append("gate must exactly match v66 source, authority, stale, human, and native policy")
    if value.get("traceability") != TRACEABILITY:
        errors.append("traceability must exactly match v67 source chain and open-gate policy")
    if value.get("traceability_checks") != TRACEABILITY_CHECKS:
        errors.append("traceability_checks must exactly match the bounded v67 checks")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    expected_fields = (
        ("traceability_id", TRACEABILITY_ID),
        ("gate_status", "open"),
        ("traceability_mode", "exact"),
        ("source_id", SOURCE_ID),
        ("source_mode", "exact"),
        ("source_readiness_id", SOURCE_READINESS_ID),
        ("source_readiness_status", "open"),
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
        return [f"traceability/gate unreadable: {exc}"]
    return validate_traceability_gate(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("traceability_gate", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.traceability_gate)
    if errors:
        print("ACCESSIBILITY_CAPTION_TRACEABILITY_GATE_V67_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_TRACEABILITY_GATE_V67_READY: gate remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
