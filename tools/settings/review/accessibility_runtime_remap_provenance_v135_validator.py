#!/usr/bin/env python3
"""Validate v135 accessibility runtime remapping provenance evidence."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_runtime_remap_provenance_v135_evidence_v1"
SOURCE_SCHEMA = "runtime_input_remap_v1"
SCHEMA_VERSION = "v135"
SOURCE_ID = "runtime-input-remap"
CONTRACT_ID = "runtime-accessibility-presentation"
OPEN_REVIEW_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
RECORD_STATUSES = {"planned", "pending", "not_performed"}
EVIDENCE_KINDS = {"log", "image", "report", "video"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")

REMAP_POLICY = {
    "profile_replacement": "complete_roster_atomic",
    "conflicts": "reject_ambiguous_bindings",
    "deadzone_range": [0.0, 1.0],
    "curve_range": [0.1, 4.0],
    "hold_toggle": "per_action_choice",
    "glyphs": "input_family_presentation_only",
    "hardware_validation": "not_run",
}
BINDING = {
    "source_schema": SOURCE_SCHEMA,
    "source_id": SOURCE_ID,
    "contract_id": CONTRACT_ID,
    "policy_mode": "exact",
    "stale_policy": "reject_stale_binding_generation",
    "human_gate": "open",
    "native_policy": "not_run",
}
AUTHORITY = {
    "presentation_only": True,
    "input_write_authority": False,
    "settings_read_authority": False,
    "settings_write_authority": False,
    "audio_authority": False,
    "caption_queue_authority": False,
    "gameplay_authority": False,
    "network_authority": False,
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha256(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256.fullmatch(value))


def _evidence(value: Any, errors: list[str]) -> None:
    if value is None:
        return
    if not isinstance(value, list) or not value:
        errors.append("evidence must be null or a non-empty list")
        return
    for index, item in enumerate(value):
        prefix = f"evidence[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = item.get("kind")
        if not isinstance(kind, str) or kind not in EVIDENCE_KINDS:
            errors.append(f"{prefix}.kind must be log, image, report, or video")
        if not _text(item.get("path")):
            errors.append(f"{prefix}.path must be non-empty text")
        if not _sha256(item.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")


def validate_runtime_remap_provenance(value: Any) -> list[str]:
    """Return remapping provenance violations without raising."""
    if not isinstance(value, dict):
        return ["runtime remap provenance record must be an object"]
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
    if value.get("human_review_status") not in OPEN_REVIEW_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("native_render_status") != "not_run":
        errors.append("native_render_status must remain not_run")
    for key in ("human_review_performed", "native_render_performed", "policy_verified", "runtime_claimed", "stale_payload_mutation"):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")
    if value.get("remap_policy") != REMAP_POLICY:
        errors.append("remap_policy must exactly match the v135 remapping and hardware boundary")
    if value.get("binding") != BINDING:
        errors.append("binding must exactly match the v135 profile, stale, human, and native policy")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match the presentation-only/input-boundary policy")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    for key, expected in (("source_id", SOURCE_ID), ("contract_id", CONTRACT_ID), ("provenance_source_of_truth", "runtime_remap_profile")):
        if value.get(key) != expected:
            errors.append(f"{key} must be {expected}")
    if value.get("status") not in RECORD_STATUSES:
        errors.append("status must remain planned, pending, or not_performed")
    _evidence(value.get("evidence"), errors)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"runtime remap provenance unreadable: {exc}"]
    return validate_runtime_remap_provenance(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provenance", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.provenance)
    if errors:
        print("ACCESSIBILITY_RUNTIME_REMAP_PROVENANCE_V135_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_RUNTIME_REMAP_PROVENANCE_V135_READY: review and native gates remain open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
