#!/usr/bin/env python3
"""Validate v21 cleanup reconciliation digest agreement summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_reconciliation_digest_agreement_summary_v21"
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
    if summary.get("claim") != "AUTOMATED_RECONCILIATION_DIGEST_ONLY":
        errors.append("claim must be AUTOMATED_RECONCILIATION_DIGEST_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    record_ids = summary.get("record_ids")
    if not _ordered_unique(record_ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    agreed = summary.get("agreed_digest")
    if not _digest(agreed):
        errors.append("agreed_digest must be a lowercase 64-character digest")

    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
        records = []
    ids: set[str] = set()
    digests: set[str] = set()
    for index, record in enumerate(records):
        prefix = f"records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        record_id = record.get("record_id")
        if not _text(record_id):
            errors.append(f"{prefix}.record_id is required")
        elif record_id in ids:
            errors.append(f"{prefix}.record_id is duplicated")
        else:
            ids.add(record_id)
        if isinstance(record_ids, list) and record_id not in record_ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        digest = record.get("reconciliation_digest")
        if not _digest(digest):
            errors.append(f"{prefix}.reconciliation_digest must be a lowercase 64-character digest")
        else:
            digests.add(digest)
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("agreement_pass") is not True:
            errors.append(f"{prefix}.agreement_pass must be true")
    if isinstance(record_ids, list) and ids != set(record_ids):
        errors.append("record_ids must exactly match records")
    if len(digests) > 1:
        errors.append("records reconciliation_digest values must agree")
    if digests and agreed not in digests:
        errors.append("agreed_digest must match records")
    if summary.get("agreement_pass") is not True:
        errors.append("agreement_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_RECONCILIATION_DIGEST_V21_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_RECONCILIATION_DIGEST_V21_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
