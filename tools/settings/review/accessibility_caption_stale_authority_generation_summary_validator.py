#!/usr/bin/env python3
"""Validate a summary handoff for caption stale authority/generation evidence.

The summary is a detached review index.  It does not execute generation
guards, mutate settings or gameplay, enqueue captions, play audio, render UI,
or claim human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_stale_authority_generation_summary_v1"
SOURCE_SCHEMA = "accessibility_caption_stale_authority_generation_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
AUTHORITY_CLAIMS = {
    "presentation_only": True,
    "audio_authority": False,
    "audio_playback": False,
    "caption_queue_authority": False,
    "settings_authority": False,
    "gameplay_authority": False,
    "network_authority": False,
}
GENERATION_CLAIMS = {
    "initial_generation": 0,
    "reset_step": 1,
    "stale_policy": "reject_less_or_greater_generation",
    "generation_owner": "caption-presentation-service",
}
SUMMARY_COUNTS = {"scenario_count": 6, "check_count": 6, "observed_count": 0, "issue_count": 0}
REQUIRED_SECTIONS = ("authority", "generation", "coverage", "gate")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _references(value: Any, errors: list[str]) -> None:
    if value is None:
        return
    if not isinstance(value, list):
        errors.append("evidence must be null or a non-empty evidence list")
        return
    if not value:
        errors.append("evidence must be null or a non-empty evidence list")
        return
    for index, reference in enumerate(value):
        prefix = f"evidence[{index}]"
        if not isinstance(reference, dict):
            errors.append(f"{prefix} must be an object")
            continue
        kind = reference.get("kind")
        if not isinstance(kind, str) or kind not in EVIDENCE_KINDS:
            errors.append(f"{prefix}.kind must be log, video, image, or report")
        if not _text(reference.get("path")):
            errors.append(f"{prefix}.path must be non-empty text")
        if not _sha(reference.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a lowercase digest")


def validate_summary(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open gate."""
    if not isinstance(value, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("source_schema") != SOURCE_SCHEMA:
        errors.append(f"source_schema must be {SOURCE_SCHEMA}")
    for key in ("source_revision", "service_source", "consumer_boundary", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    human_review_status = value.get("human_review_status")
    if not isinstance(human_review_status, str) or human_review_status not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    native_render_status = value.get("native_render_status")
    if not isinstance(native_render_status, str) or native_render_status not in {"not_run", "planned", "blocked"}:
        errors.append("native_render_status must remain not_run, planned, or blocked")
    for key, expected in (("human_review_performed", False), ("native_render_performed", False)):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("service_id") != "caption-presentation-service":
        errors.append("service_id must identify caption-presentation-service")
    if value.get("contract_id") != "caption-accessibility-contract":
        errors.append("contract_id must identify caption-accessibility-contract")
    if value.get("authority") != AUTHORITY_CLAIMS:
        errors.append("authority must exactly match the presentation-only authority claims")
    if value.get("generation") != GENERATION_CLAIMS:
        errors.append("generation must exactly match the frozen generation claims")
    if value.get("counts") != SUMMARY_COUNTS:
        errors.append("counts must exactly match six planned scenarios/checks and zero observations/issues")
    sections = value.get("sections")
    if sections != list(REQUIRED_SECTIONS):
        errors.append("sections must exactly match authority, generation, coverage, and gate")
    coverage = value.get("coverage")
    if not isinstance(coverage, dict):
        errors.append("coverage must be an object")
    else:
        if coverage.get("scenarios") != "all_planned":
            errors.append("coverage.scenarios must be all_planned")
        if coverage.get("checks") != "all_planned":
            errors.append("coverage.checks must be all_planned")
        if coverage.get("human_review") != "not_performed":
            errors.append("coverage.human_review must be not_performed")
        if coverage.get("native_render") != "not_run":
            errors.append("coverage.native_render must be not_run")
    gate = value.get("gate")
    if not isinstance(gate, dict):
        errors.append("gate must be an object")
    else:
        gate_status = gate.get("status")
        if not isinstance(gate_status, str) or gate_status not in OPEN_STATUSES:
            errors.append("gate.status must remain open")
        if gate.get("review_required") is not True:
            errors.append("gate.review_required must be true")
        if gate.get("native_render_required") is not True:
            errors.append("gate.native_render_required must be true")
    _references(value.get("evidence"), errors)
    for key in AUTHORITY_CLAIMS:
        if value.get(key) is not AUTHORITY_CLAIMS[key]:
            errors.append(f"{key} must be {str(AUTHORITY_CLAIMS[key]).lower()}")
    if value.get("stale_payload_mutation") is not False:
        errors.append("stale_payload_mutation must be false")
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"summary unreadable: {exc}"]
    return validate_summary(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.summary)
    if errors:
        print("ACCESSIBILITY_CAPTION_STALE_AUTHORITY_SUMMARY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_STALE_AUTHORITY_SUMMARY_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
