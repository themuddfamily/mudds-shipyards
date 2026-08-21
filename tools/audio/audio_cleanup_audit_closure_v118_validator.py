#!/usr/bin/env python3
"""Validate v118 audio cleanup audit/closure summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "audio_cleanup_audit_closure_v118"
CLAIM = "AUTOMATED_AUDIT_CLOSURE_ONLY"
NOT_RUN = "NOT_RUN"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def _ordered_unique(value: Any) -> bool:
    return (isinstance(value, list) and bool(value) and all(_text(item) for item in value)
            and len(value) == len(set(value)) and value == sorted(value))


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "audit_bundle", "audit_id", "closure_id"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != CLAIM:
        errors.append(f"claim must be {CLAIM}")
    if summary.get("native_status") != NOT_RUN:
        errors.append("native_status must be NOT_RUN")
    if summary.get("stale_callback_status") != NOT_RUN:
        errors.append("stale_callback_status must be NOT_RUN")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    for key in ("audit_digest", "closure_digest"):
        if not _digest(summary.get(key)):
            errors.append(f"{key} must be a lowercase 64-character digest")
    ids = summary.get("record_ids")
    if not _ordered_unique(ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
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
        if isinstance(ids, list) and record_id not in ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        for key in ("audit_digest", "closure_digest"):
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
            elif record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        for key in ("audit_id", "closure_id"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if not _text(record.get("audit")):
            errors.append(f"{prefix}.audit is required")
        if not _text(record.get("closure")):
            errors.append(f"{prefix}.closure is required")
        if record.get("closure_pass") is not True:
            errors.append(f"{prefix}.closure_pass must be true")
    if isinstance(ids, list) and seen != set(ids):
        errors.append("record_ids must exactly match records")
    if summary.get("audit_closure_pass") is not True:
        errors.append("audit_closure_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_AUDIT_CLOSURE_V118_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_AUDIT_CLOSURE_V118_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
