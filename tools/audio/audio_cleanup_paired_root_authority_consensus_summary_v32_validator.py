#!/usr/bin/env python3
"""Validate v32 paired root/authority consensus summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "audio_cleanup_paired_root_authority_consensus_summary_v32"
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
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization", "root_id", "authority_id"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_PAIRED_ROOT_AUTHORITY_CONSENSUS_ONLY":
        errors.append("claim must be AUTOMATED_PAIRED_ROOT_AUTHORITY_CONSENSUS_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    record_ids = summary.get("record_ids")
    consensus_ids = summary.get("consensus_record_ids")
    if not _roster(record_ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    if not _roster(consensus_ids):
        errors.append("consensus_record_ids must be ordered, unique, and non-empty")
    if isinstance(record_ids, list) and isinstance(consensus_ids, list) and consensus_ids != record_ids:
        errors.append("consensus_record_ids must match record_ids")
    for key in ("root_summary_digest", "root_reconciliation_digest", "authority_summary_digest", "authority_reconciliation_digest"):
        if not _digest(summary.get(key)):
            errors.append(f"{key} must be a lowercase 64-character digest")
    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
        records = []
    seen: set[str] = set()
    pairs: set[tuple[str, str, str, str]] = set()
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
        if isinstance(record_ids, list) and rid not in record_ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        keys = ("summary_digest", "reconciliation_digest", "authority_summary_digest", "authority_reconciliation_digest")
        for key in keys:
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
        if all(_digest(record.get(key)) for key in keys):
            pairs.add(tuple(record[key] for key in keys))
        if record.get("root_id") != summary.get("root_id"):
            errors.append(f"{prefix}.root_id must match summary root_id")
        if record.get("authority_id") != summary.get("authority_id"):
            errors.append(f"{prefix}.authority_id must match summary authority_id")
        for key in ("authority_summary_digest", "authority_reconciliation_digest"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("consensus_pass") is not True:
            errors.append(f"{prefix}.consensus_pass must be true")
    if isinstance(record_ids, list) and seen != set(record_ids):
        errors.append("record_ids must exactly match records")
    roots = [r for r in records if isinstance(r, dict) and r.get("record_id") == summary.get("root_id")]
    if not roots:
        errors.append("root_id must reference a record")
    elif roots[0].get("summary_digest") != summary.get("root_summary_digest"):
        errors.append("root_summary_digest must match root record")
    if len(pairs) > 1:
        errors.append("records paired digests must agree")
    if summary.get("paired_consensus_pass") is not True:
        errors.append("paired_consensus_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_PAIRED_ROOT_AUTHORITY_CONSENSUS_V32_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_PAIRED_ROOT_AUTHORITY_CONSENSUS_V32_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
