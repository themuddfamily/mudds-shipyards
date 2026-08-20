#!/usr/bin/env python3
"""Validate digest metadata for the caption stale-authority summary.

This detached validator checks digest scope and covered summary fields.  It
does not calculate or verify a production artifact, mutate runtime state, play
audio, render UI, or claim human accessibility review.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "accessibility_caption_stale_authority_summary_digest_evidence_v1"
SOURCE_SUMMARY_SCHEMA = "accessibility_caption_stale_authority_generation_summary_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{64}$")
DIGEST_FIELDS = ("schema", "source_schema", "source_revision", "authority", "generation", "counts", "coverage", "gate")
REQUIRED_SECTIONS = ("authority", "generation", "coverage", "gate")
DIGEST_STATUS = ("planned", "pending", "not_performed")


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
        if not _digest(reference.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")


def validate_digest(value: Any) -> list[str]:
    """Return blocking errors; empty means digest metadata is review-ready."""
    if not isinstance(value, dict):
        return ["digest record must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("source_summary_schema") != SOURCE_SUMMARY_SCHEMA:
        errors.append(f"source_summary_schema must be {SOURCE_SUMMARY_SCHEMA}")
    for key in ("source_revision", "summary_path", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    human_review_status = value.get("human_review_status")
    if not isinstance(human_review_status, str) or human_review_status not in OPEN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    native_render_status = value.get("native_render_status")
    if not isinstance(native_render_status, str) or native_render_status not in {"not_run", "planned", "blocked"}:
        errors.append("native_render_status must remain not_run, planned, or blocked")
    for key, expected in (("human_review_performed", False), ("native_render_performed", False), ("digest_verified", False), ("digest_generated", False)):
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    if value.get("digest_algorithm") != "sha256":
        errors.append("digest_algorithm must be sha256")
    if value.get("digest_scope") != "canonical_summary_fields":
        errors.append("digest_scope must be canonical_summary_fields")
    if value.get("digest_status") not in DIGEST_STATUS:
        errors.append("digest_status must remain planned, pending, or not_performed")
    if not _digest(value.get("summary_digest")):
        errors.append("summary_digest must be a lowercase 64-character digest")
    if value.get("covered_fields") != list(DIGEST_FIELDS):
        errors.append("covered_fields must exactly match the frozen canonical summary fields")
    if value.get("covered_sections") != list(REQUIRED_SECTIONS):
        errors.append("covered_sections must exactly match authority, generation, coverage, and gate")
    if value.get("presentation_only") is not True:
        errors.append("presentation_only must be true")
    for key in ("audio_authority", "audio_playback", "caption_queue_authority", "settings_authority", "gameplay_authority", "network_authority"):
        if value.get(key) is not False:
            errors.append(f"{key} must be false")
    _references(value.get("evidence"), errors)
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"digest record unreadable: {exc}"]
    return validate_digest(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("digest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.digest)
    if errors:
        print("ACCESSIBILITY_CAPTION_STALE_AUTHORITY_DIGEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ACCESSIBILITY_CAPTION_STALE_AUTHORITY_DIGEST_READY: human review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
