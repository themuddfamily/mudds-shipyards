#!/usr/bin/env python3
"""Validate v119 accessibility settings-to-runtime provenance evidence.

The record describes the handoff boundary only.  It does not apply settings,
write user data, inspect hardware, or turn automated evidence into a release
claim.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_settings_runtime_provenance_v119_evidence_v1"
SOURCE_SCHEMA = "runtime_settings_accessibility_handoff_v1"
SCHEMA_VERSION = "v119"
SOURCE_ID = "runtime-settings-accessibility-handoff"
CONTRACT_ID = "runtime-accessibility-presentation"
PROFILE_OWNER = "GameFlow/RuntimeSettings"
OPEN_REVIEW_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
RECORD_STATUSES = {"planned", "pending", "not_performed"}
EVIDENCE_KINDS = {"log", "image", "report", "video"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")

PROVENANCE = {
    "source_of_truth": "retained_settings_profile",
    "profile_owner": PROFILE_OWNER,
    "runtime_handoff": SOURCE_ID,
    "presentation_consumer": CONTRACT_ID,
    "migration_boundary": "versioned_profile_before_presentation",
    "reset_boundary": "validated_profile_reset_before_presentation",
    "reentry_boundary": "same_generation_snapshot_reapplied",
    "hardware_boundary": "not_run",
}
BINDING = {
    "source_schema": SOURCE_SCHEMA,
    "source_id": SOURCE_ID,
    "contract_id": CONTRACT_ID,
    "profile_owner": PROFILE_OWNER,
    "provenance_mode": "exact",
    "stale_policy": "reject_stale_profile_generation",
    "human_gate": "open",
    "native_policy": "not_run",
}
AUTHORITY = {
    "presentation_only": True,
    "settings_read_authority": False,
    "settings_write_authority": False,
    "audio_authority": False,
    "audio_playback": False,
    "caption_queue_authority": False,
    "gameplay_authority": False,
    "network_authority": False,
}
SOURCE_FILES = [
    "scripts/game/game_flow.gd",
    "scripts/settings/runtime_settings.gd",
    "scripts/recovery/safe_start_recovery_policy.gd",
    "scripts/ui/runtime_accessibility_presentation.gd",
]


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
    paths: set[str] = set()
    for index, item in enumerate(value):
        prefix = f"evidence[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if not isinstance(item.get("kind"), str) or item.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{prefix}.kind must be log, image, report, or video")
        path = item.get("path")
        if not _text(path):
            errors.append(f"{prefix}.path must be non-empty text")
        elif path in paths:
            errors.append(f"{prefix}.path must be unique")
        else:
            paths.add(path)
        if not _sha256(item.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")


def validate_settings_runtime_provenance(value: Any) -> list[str]:
    """Return handoff provenance violations without raising."""
    if not isinstance(value, dict):
        return ["settings runtime provenance record must be an object"]
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
    for key in ("human_review_performed", "native_render_performed", "handoff_verified", "runtime_claimed", "stale_payload_mutation"):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")
    if value.get("provenance") != PROVENANCE:
        errors.append("provenance must exactly match the v119 settings-to-runtime handoff")
    if value.get("binding") != BINDING:
        errors.append("binding must exactly match the v119 owner, generation, human, and native policy")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match the read/write-free presentation boundary")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("source_files") != SOURCE_FILES:
        errors.append("source_files must exactly list the settings owner, recovery boundary, and presentation consumer")
    expected = {
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "profile_owner": PROFILE_OWNER,
        "provenance_source_of_truth": "retained_settings_profile",
    }
    for key, expected_value in expected.items():
        if value.get(key) != expected_value:
            errors.append(f"{key} must be {expected_value}")
    if value.get("status") not in RECORD_STATUSES:
        errors.append("status must remain planned, pending, or not_performed")
    _evidence(value.get("evidence"), errors)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"settings runtime provenance unreadable: {exc}"]
    return validate_settings_runtime_provenance(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provenance", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.provenance)
    if errors:
        print("ACCESSIBILITY_SETTINGS_RUNTIME_PROVENANCE_V119_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_SETTINGS_RUNTIME_PROVENANCE_V119_READY: review and native gates remain open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
