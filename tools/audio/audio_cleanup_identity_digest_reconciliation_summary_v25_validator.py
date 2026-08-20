#!/usr/bin/env python3
"""Validate v25 cleanup identity/digest reconciliation summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_identity_digest_reconciliation_summary_v25"
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
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_IDENTITY_DIGEST_ONLY":
        errors.append("claim must be AUTOMATED_IDENTITY_DIGEST_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids = summary.get("identity_ids")
    if not _ordered_unique(ids):
        errors.append("identity_ids must be ordered, unique, and non-empty")
    entries = summary.get("identity_entries")
    entry_ids: set[str] = set()
    entry_digests: set[str] = set()
    if not isinstance(entries, list) or not entries:
        errors.append("identity_entries must be a non-empty array")
        entries = []
    for index, entry in enumerate(entries):
        prefix = f"identity_entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        identity_id = entry.get("identity_id")
        if not _text(identity_id):
            errors.append(f"{prefix}.identity_id is required")
        elif identity_id in entry_ids:
            errors.append(f"{prefix}.identity_id is duplicated")
        else:
            entry_ids.add(identity_id)
        if isinstance(ids, list) and identity_id not in ids:
            errors.append(f"{prefix}.identity_id must be in identity_ids")
        digest = entry.get("digest")
        if not _digest(digest):
            errors.append(f"{prefix}.digest must be a lowercase 64-character digest")
        else:
            entry_digests.add(digest)
        if not _text(entry.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if entry.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
    if isinstance(ids, list) and entry_ids != set(ids):
        errors.append("identity_entries must exactly cover identity_ids")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
    record_ids: set[str] = set()
    record_digests: set[str] = set()
    for index, record in enumerate(records):
        prefix = f"records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        record_id = record.get("record_id")
        if not _text(record_id):
            errors.append(f"{prefix}.record_id is required")
        elif record_id in record_ids:
            errors.append(f"{prefix}.record_id is duplicated")
        else:
            record_ids.add(record_id)
        if record.get("identity_ids") != ids:
            errors.append(f"{prefix}.identity_ids must match ordered summary roster")
        digest = record.get("identity_set_digest")
        if not _digest(digest):
            errors.append(f"{prefix}.identity_set_digest must be a lowercase 64-character digest")
        else:
            record_digests.add(digest)
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
    if len(record_digests) > 1:
        errors.append("records identity_set_digest values must agree")
    if summary.get("reconciliation_pass") is not True:
        errors.append("reconciliation_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_IDENTITY_DIGEST_V25_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_IDENTITY_DIGEST_V25_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
