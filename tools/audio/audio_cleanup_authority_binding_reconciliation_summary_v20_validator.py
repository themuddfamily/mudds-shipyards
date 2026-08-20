#!/usr/bin/env python3
"""Validate v20 cleanup authority-binding reconciliation summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_authority_binding_reconciliation_summary_v20"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_EXCLUSIONS = {"gameplay_damage", "gameplay_phase", "reward"}


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
    if summary.get("claim") != "AUTOMATED_AUTHORITY_RECONCILIATION_ONLY":
        errors.append("claim must be AUTOMATED_AUTHORITY_RECONCILIATION_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    binding_ids = summary.get("binding_ids")
    if not _ordered_unique(binding_ids):
        errors.append("binding_ids must be ordered, unique, and non-empty")
    authority_digest = summary.get("authority_digest")
    if not _digest(authority_digest):
        errors.append("authority_digest must be a lowercase 64-character digest")

    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
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
        if record.get("binding_ids") != binding_ids:
            errors.append(f"{prefix}.binding_ids must match ordered summary roster")
        digest = record.get("authority_digest")
        if not _digest(digest):
            errors.append(f"{prefix}.authority_digest must be a lowercase 64-character digest")
        else:
            record_digests.add(digest)
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        exclusions = record.get("authority_exclusions")
        if not isinstance(exclusions, list) or not REQUIRED_EXCLUSIONS.issubset(exclusions):
            errors.append(f"{prefix}.authority_exclusions must include gameplay_damage, gameplay_phase, and reward")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
    if len(record_digests) > 1:
        errors.append("records authority_digest values must agree")
    if record_digests and authority_digest not in record_digests:
        errors.append("authority_digest must match records")
    if summary.get("reconciliation_pass") is not True:
        errors.append("reconciliation_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_AUTHORITY_RECONCILIATION_V20_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_AUTHORITY_RECONCILIATION_V20_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
