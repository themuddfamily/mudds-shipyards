#!/usr/bin/env python3
"""Validate v118 runtime caption/accessibility provenance evidence.

This validator records the ownership chain for the detached runtime UI adapter
without treating automated composition checks as a native or human review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_runtime_provenance_v118_evidence_v1"
SOURCE_SCHEMA = "runtime_accessibility_presentation_v1"
SCHEMA_VERSION = "v118"
SOURCE_ID = "runtime-accessibility-presentation"
CONTRACT_ID = "runtime-accessibility-presentation"
CAPTION_OWNER = "caption-presentation-service"
OPEN_REVIEW_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
RECORD_STATUSES = {"planned", "pending", "not_performed"}
EVIDENCE_KINDS = {"log", "image", "report", "video"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")

PROVENANCE = {
    "source_of_truth": "presentation_only",
    "runtime_adapter": SOURCE_ID,
    "caption_policy": "caption-accessibility-contract",
    "visual_policy": "accessibility-visual-preset",
    "audio_fallback_policy": "audio-accessibility-preset",
    "safe_area_policy": "ultrawide-safe-area-contract",
    "server_browser_prompt_policy": "server-browser-presenter",
    "event_authority": "caller_observation",
}
BINDING = {
    "source_schema": SOURCE_SCHEMA,
    "source_id": SOURCE_ID,
    "contract_id": CONTRACT_ID,
    "caption_owner": CAPTION_OWNER,
    "provenance_mode": "exact",
    "stale_policy": "reject_stale_revision",
    "human_gate": "open",
    "native_policy": "not_run",
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
SOURCE_FILES = [
    "scripts/ui/runtime_accessibility_presentation.gd",
    "scripts/ui/caption_accessibility_contract.gd",
    "scripts/ui/accessibility_visual_preset.gd",
    "scripts/audio/audio_accessibility_preset.gd",
    "scripts/ui/ultrawide_safe_area_contract.gd",
    "scripts/ui/server_browser_presenter.gd",
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
        kind = item.get("kind")
        if not isinstance(kind, str) or kind not in EVIDENCE_KINDS:
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


def validate_runtime_caption_provenance(value: Any) -> list[str]:
    """Return provenance violations without raising for malformed records."""
    if not isinstance(value, dict):
        return ["runtime caption provenance record must be an object"]
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
    for key in (
        "human_review_performed",
        "native_render_performed",
        "provenance_verified",
        "runtime_claimed",
        "stale_payload_mutation",
    ):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")
    if value.get("provenance") != PROVENANCE:
        errors.append("provenance must exactly match the v118 presentation ownership chain")
    if value.get("binding") != BINDING:
        errors.append("binding must exactly match the v118 source, owner, stale, human, and native policy")
    if value.get("authority") != AUTHORITY:
        errors.append("authority must exactly match presentation-only claims")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("source_files") != SOURCE_FILES:
        errors.append("source_files must exactly list the runtime adapter and its five presentation policy owners")
    expected = {
        "source_id": SOURCE_ID,
        "contract_id": CONTRACT_ID,
        "caption_owner": CAPTION_OWNER,
        "provenance_source_of_truth": "presentation_only",
        "status": None,
    }
    for key, expected_value in expected.items():
        if key == "status":
            if value.get(key) not in RECORD_STATUSES:
                errors.append("status must remain planned, pending, or not_performed")
        elif value.get(key) != expected_value:
            errors.append(f"{key} must be {expected_value}")
    _evidence(value.get("evidence"), errors)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"runtime caption provenance unreadable: {exc}"]
    return validate_runtime_caption_provenance(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provenance", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.provenance)
    if errors:
        print("ACCESSIBILITY_CAPTION_RUNTIME_PROVENANCE_V118_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_RUNTIME_PROVENANCE_V118_READY: review and native gates remain open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
