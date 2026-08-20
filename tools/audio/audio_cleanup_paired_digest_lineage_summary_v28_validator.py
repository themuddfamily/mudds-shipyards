#!/usr/bin/env python3
"""Validate v28 paired-digest cleanup lineage summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_paired_digest_lineage_summary_v28"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def _ordered_unique(value: Any) -> bool:
    return (
        isinstance(value, list)
        and bool(value)
        and all(_text(item) for item in value)
        and len(value) == len(set(value))
        and value == sorted(value)
    )


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_PAIRED_DIGEST_LINEAGE_ONLY":
        errors.append("claim must be AUTOMATED_PAIRED_DIGEST_LINEAGE_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids = summary.get("record_ids")
    if not _ordered_unique(ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    for key in ("root_summary_digest", "root_reconciliation_digest"):
        if not _digest(summary.get(key)):
            errors.append(f"{key} must be a lowercase 64-character digest")

    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
        records = []
    record_by_id: dict[str, dict[str, Any]] = {}
    pairs: set[tuple[str, str]] = set()
    for index, record in enumerate(records):
        prefix = f"records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        record_id = record.get("record_id")
        if not _text(record_id):
            errors.append(f"{prefix}.record_id is required")
        elif record_id in record_by_id:
            errors.append(f"{prefix}.record_id is duplicated")
        else:
            record_by_id[record_id] = record
        if isinstance(ids, list) and record_id not in ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        summary_digest = record.get("summary_digest")
        reconciliation_digest = record.get("reconciliation_digest")
        if not _digest(summary_digest):
            errors.append(f"{prefix}.summary_digest must be a lowercase 64-character digest")
        if not _digest(reconciliation_digest):
            errors.append(f"{prefix}.reconciliation_digest must be a lowercase 64-character digest")
        if _digest(summary_digest) and _digest(reconciliation_digest):
            pairs.add((summary_digest, reconciliation_digest))
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("lineage_pass") is not True:
            errors.append(f"{prefix}.lineage_pass must be true")

    if isinstance(ids, list) and set(record_by_id) != set(ids):
        errors.append("record_ids must exactly match records")
    if records:
        first = records[0] if isinstance(records[0], dict) else {}
        if first.get("parent_record_id") is not None:
            errors.append("records[0].parent_record_id must be null")
        if _digest(first.get("summary_digest")) and first.get("summary_digest") != summary.get("root_summary_digest"):
            errors.append("root_summary_digest must match first record")
        if _digest(first.get("reconciliation_digest")) and first.get("reconciliation_digest") != summary.get("root_reconciliation_digest"):
            errors.append("root_reconciliation_digest must match first record")
    for index, record in enumerate(records[1:], start=1):
        prefix = f"records[{index}]"
        if not isinstance(record, dict):
            continue
        parent_id = record.get("parent_record_id")
        if not _text(parent_id):
            errors.append(f"{prefix}.parent_record_id is required")
            continue
        parent = record_by_id.get(parent_id)
        if parent is None:
            errors.append(f"{prefix}.parent_record_id must reference a record")
            continue
        if record.get("parent_summary_digest") != parent.get("summary_digest"):
            errors.append(f"{prefix}.parent_summary_digest must match parent")
        if record.get("parent_reconciliation_digest") != parent.get("reconciliation_digest"):
            errors.append(f"{prefix}.parent_reconciliation_digest must match parent")
    if len(pairs) > 1:
        errors.append("records digest pairs must agree")
    if summary.get("paired_lineage_pass") is not True:
        errors.append("paired_lineage_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_PAIRED_DIGEST_LINEAGE_V28_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_PAIRED_DIGEST_LINEAGE_V28_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
