#!/usr/bin/env python3
"""Validate v6 cleanup-digest input-roster integrity and canonical agreement."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_input_roster_integrity_summary_v6"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def _ordered_unique_paths(value: Any) -> bool:
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
    if summary.get("claim") != "AUTOMATED_ROSTER_INTEGRITY_ONLY":
        errors.append("claim must be AUTOMATED_ROSTER_INTEGRITY_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if summary.get("algorithm") != "SHA-256":
        errors.append("algorithm must be SHA-256")
    roster = summary.get("input_manifests")
    if not _ordered_unique_paths(roster):
        errors.append("input_manifests must be ordered, unique, and non-empty")
    digest = summary.get("canonical_input_sha256")
    if not _digest(digest):
        errors.append("canonical_input_sha256 must be a lowercase 64-character digest")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
    ids: set[str] = set()
    record_digests: set[str] = set()
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
        if record.get("input_manifests") != roster:
            errors.append(f"{prefix}.input_manifests must match ordered summary roster")
        record_digest = record.get("canonical_input_sha256")
        if not _digest(record_digest):
            errors.append(f"{prefix}.canonical_input_sha256 must be a lowercase 64-character digest")
        else:
            record_digests.add(record_digest)
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("integrity_pass") is not True:
            errors.append(f"{prefix}.integrity_pass must be true")
    if len(record_digests) > 1:
        errors.append("records canonical_input_sha256 digests must agree")
    if record_digests and digest not in record_digests:
        errors.append("canonical_input_sha256 must match record digests")
    if summary.get("integrity_pass") is not True:
        errors.append("integrity_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_INPUT_ROSTER_V6_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_INPUT_ROSTER_V6_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
