#!/usr/bin/env python3
"""Validate v38 linked authority/reconciliation digest summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "audio_cleanup_authority_reconciliation_linked_digest_summary_v38"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def _roster(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value)) and value == sorted(value)


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization", "authority_id", "authority_record_id", "reconciliation_record_id"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_LINKED_AUTHORITY_RECONCILIATION_DIGEST_ONLY":
        errors.append("claim must be AUTOMATED_LINKED_AUTHORITY_RECONCILIATION_DIGEST_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids = summary.get("record_ids")
    if not _roster(ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    for key in ("authority_digest", "reconciliation_digest"):
        if not _digest(summary.get(key)):
            errors.append(f"{key} must be a lowercase 64-character digest")
    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
        records = []
    seen: set[str] = set()
    pairs: set[tuple[str, str]] = set()
    for index, record in enumerate(records):
        prefix = f"records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        rid = record.get("record_id")
        if not _text(rid):
            errors.append(f"{prefix}.record_id is required")
        elif rid in seen:
            errors.append(f"{prefix}.record_id is duplicated")
        else:
            seen.add(rid)
        if isinstance(ids, list) and rid not in ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        for key in ("authority_digest", "reconciliation_digest"):
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
            elif record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        pair = (record.get("authority_digest"), record.get("reconciliation_digest"))
        if _digest(pair[0]) and _digest(pair[1]):
            pairs.add(pair)
        if record.get("authority_id") != summary.get("authority_id"):
            errors.append(f"{prefix}.authority_id must match summary")
        if record.get("authority_record_id") != summary.get("authority_record_id"):
            errors.append(f"{prefix}.authority_record_id must match summary")
        if record.get("reconciliation_record_id") != summary.get("reconciliation_record_id"):
            errors.append(f"{prefix}.reconciliation_record_id must match summary")
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("link_pass") is not True:
            errors.append(f"{prefix}.link_pass must be true")
    if isinstance(ids, list) and seen != set(ids):
        errors.append("record_ids must exactly match records")
    if isinstance(ids, list):
        for key in ("authority_record_id", "reconciliation_record_id"):
            if summary.get(key) not in ids:
                errors.append(f"{key} must reference a record")
    if len(pairs) > 1:
        errors.append("records linked digest pairs must agree")
    if summary.get("linked_reconciliation_pass") is not True:
        errors.append("linked_reconciliation_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_AUTHORITY_RECONCILIATION_LINKED_V38_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_AUTHORITY_RECONCILIATION_LINKED_V38_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
