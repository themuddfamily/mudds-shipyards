#!/usr/bin/env python3
"""Validate v305 audio cleanup evidence/state summaries without runtime claims."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "audio_cleanup_evidence_state_v305"
CLAIM = "AUTOMATED_EVIDENCE_STATE_ONLY"
NOT_RUN = "NOT_RUN"
STATES = {"open", "ready", "closed"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")
BOUNDARY_FIELDS = ("detached_status", "native_status", "hardware_status", "human_review_status")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _roster(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value)) and value == sorted(value)


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "evidence_id", "state_model"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != CLAIM:
        errors.append(f"claim must be {CLAIM}")
    for key in BOUNDARY_FIELDS:
        if summary.get(key) != NOT_RUN:
            errors.append(f"{key} must be NOT_RUN")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if summary.get("state") not in STATES:
        errors.append("state must be open, ready, or closed")
    record_ids = summary.get("record_ids")
    if not _roster(record_ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    for key in ("evidence_digest", "state_digest"):
        if not _digest(summary.get(key)):
            errors.append(f"{key} must be a lowercase 64-character digest")
    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
        records = []
    seen: set[str] = set()
    for index, record in enumerate(records):
        prefix = f"records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        record_id = record.get("record_id")
        if not _text(record_id):
            errors.append(f"{prefix}.record_id is required")
        elif record_id in seen:
            errors.append(f"{prefix}.record_id is duplicated")
        else:
            seen.add(record_id)
        if isinstance(record_ids, list) and record_id not in record_ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        for key in ("evidence_digest", "state_digest"):
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
            elif record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        for key in ("evidence_id", "state_model", "state"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("state_pass") is not True:
            errors.append(f"{prefix}.state_pass must be true")
    if isinstance(record_ids, list) and seen != set(record_ids):
        errors.append("record_ids must exactly match records")
    if summary.get("evidence_state_pass") is not True:
        errors.append("evidence_state_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    summary = json.loads(parser.parse_args(argv).summary.read_text(encoding="utf-8"))
    errors = validate_summary(summary)
    if errors:
        print("AUDIO_CLEANUP_EVIDENCE_STATE_V305_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_EVIDENCE_STATE_V305_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
