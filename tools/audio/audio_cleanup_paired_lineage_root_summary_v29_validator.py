#!/usr/bin/env python3
"""Validate v29 paired lineage-root cleanup summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_paired_lineage_root_summary_v29"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def _ordered_unique(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value)) and value == sorted(value)


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization", "lineage_root_id"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_PAIRED_LINEAGE_ROOT_ONLY":
        errors.append("claim must be AUTOMATED_PAIRED_LINEAGE_ROOT_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids = summary.get("record_ids")
    if not _ordered_unique(ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    for key in ("lineage_root_summary_digest", "lineage_root_reconciliation_digest"):
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
        for key in ("summary_digest", "reconciliation_digest", "root_summary_digest", "root_reconciliation_digest"):
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
        pair = (record.get("summary_digest"), record.get("reconciliation_digest"))
        if _digest(pair[0]) and _digest(pair[1]):
            pairs.add(pair)
        if record.get("root_record_id") != summary.get("lineage_root_id"):
            errors.append(f"{prefix}.root_record_id must match lineage_root_id")
        if record.get("root_summary_digest") != summary.get("lineage_root_summary_digest"):
            errors.append(f"{prefix}.root_summary_digest must match summary root")
        if record.get("root_reconciliation_digest") != summary.get("lineage_root_reconciliation_digest"):
            errors.append(f"{prefix}.root_reconciliation_digest must match summary root")
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("root_lineage_pass") is not True:
            errors.append(f"{prefix}.root_lineage_pass must be true")
    if isinstance(ids, list) and set(record_by_id) != set(ids):
        errors.append("record_ids must exactly match records")
    if record_by_id and summary.get("lineage_root_id") not in record_by_id:
        errors.append("lineage_root_id must reference a record")
    root = record_by_id.get(summary.get("lineage_root_id"))
    if root is not None:
        if root.get("root_record_id") != summary.get("lineage_root_id"):
            errors.append("root record must self-reference lineage_root_id")
        if root.get("summary_digest") != summary.get("lineage_root_summary_digest"):
            errors.append("lineage_root_summary_digest must match root record")
        if root.get("reconciliation_digest") != summary.get("lineage_root_reconciliation_digest"):
            errors.append("lineage_root_reconciliation_digest must match root record")
    if len(pairs) > 1:
        errors.append("records digest pairs must agree")
    if summary.get("paired_root_pass") is not True:
        errors.append("paired_root_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_PAIRED_LINEAGE_ROOT_V29_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_PAIRED_LINEAGE_ROOT_V29_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
