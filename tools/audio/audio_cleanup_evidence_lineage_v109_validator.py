#!/usr/bin/env python3
"""Validate v109 audio cleanup evidence/lineage summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "audio_cleanup_evidence_lineage_v109"
CLAIM = "AUTOMATED_EVIDENCE_LINEAGE_ONLY"
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
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "evidence_id", "lineage_id"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != CLAIM:
        errors.append(f"claim must be {CLAIM}")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    for key in ("evidence_digest", "lineage_root"):
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
    leaves: set[str] = set()
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
        for key in ("evidence_digest", "lineage_root", "lineage_leaf"):
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
        if _digest(record.get("evidence_digest")) and record.get("evidence_digest") != summary.get("evidence_digest"):
            errors.append(f"{prefix}.evidence_digest must match summary")
        if _digest(record.get("lineage_root")) and record.get("lineage_root") != summary.get("lineage_root"):
            errors.append(f"{prefix}.lineage_root must match summary")
        if _digest(record.get("lineage_leaf")):
            leaves.add(record["lineage_leaf"])
        for key in ("evidence_id", "lineage_id"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("lineage_pass") is not True:
            errors.append(f"{prefix}.lineage_pass must be true")
    if isinstance(ids, list) and seen != set(ids):
        errors.append("record_ids must exactly match records")
    if len(leaves) != len(records):
        errors.append("records lineage_leaf digests must be unique")
    if summary.get("evidence_lineage_pass") is not True:
        errors.append("evidence_lineage_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_EVIDENCE_LINEAGE_V109_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_EVIDENCE_LINEAGE_V109_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
