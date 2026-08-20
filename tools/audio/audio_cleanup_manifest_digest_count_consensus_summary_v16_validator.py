#!/usr/bin/env python3
"""Validate v16 cleanup manifest digest/count consensus summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_manifest_digest_count_consensus_summary_v16"
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
    if summary.get("claim") != "AUTOMATED_MANIFEST_CONSENSUS_ONLY":
        errors.append("claim must be AUTOMATED_MANIFEST_CONSENSUS_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids = summary.get("manifest_ids")
    if not _ordered_unique(ids):
        errors.append("manifest_ids must be ordered, unique, and non-empty")
    count = summary.get("consensus_count")
    if not isinstance(count, int) or isinstance(count, bool) or count <= 0:
        errors.append("consensus_count must be a positive integer")
    elif isinstance(ids, list) and count != len(ids):
        errors.append("consensus_count must match manifest_ids length")
    digest = summary.get("consensus_digest")
    if not _digest(digest):
        errors.append("consensus_digest must be a lowercase 64-character digest")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
    record_ids: set[str] = set()
    digests: set[str] = set()
    counts: set[int] = set()
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
        if record.get("manifest_ids") != ids:
            errors.append(f"{prefix}.manifest_ids must match ordered summary roster")
        record_count = record.get("manifest_count")
        if not isinstance(record_count, int) or isinstance(record_count, bool) or record_count <= 0:
            errors.append(f"{prefix}.manifest_count must be a positive integer")
        else:
            counts.add(record_count)
        record_digest = record.get("manifest_digest")
        if not _digest(record_digest):
            errors.append(f"{prefix}.manifest_digest must be a lowercase 64-character digest")
        else:
            digests.add(record_digest)
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("consensus_pass") is not True:
            errors.append(f"{prefix}.consensus_pass must be true")
    if len(counts) > 1:
        errors.append("records manifest_count values must agree")
    if counts and count not in counts:
        errors.append("consensus_count must match records")
    if len(digests) > 1:
        errors.append("records manifest_digest values must agree")
    if digests and digest not in digests:
        errors.append("consensus_digest must match records")
    if summary.get("consensus_pass") is not True:
        errors.append("consensus_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_MANIFEST_CONSENSUS_V16_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_MANIFEST_CONSENSUS_V16_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
