#!/usr/bin/env python3
"""Validate v5 cross-record reproducibility consensus for cleanup digests."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_reproducibility_summary_v5"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def _paths(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_CROSS_RECORD_ONLY":
        errors.append("claim must be AUTOMATED_CROSS_RECORD_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if summary.get("algorithm") != "SHA-256":
        errors.append("algorithm must be SHA-256")
    if not _digest(summary.get("consensus_summary_sha256")):
        errors.append("consensus_summary_sha256 must be a lowercase 64-character digest")
    if not _digest(summary.get("consensus_input_sha256")):
        errors.append("consensus_input_sha256 must be a lowercase 64-character digest")
    roster = summary.get("input_manifests")
    if not _paths(roster):
        errors.append("input_manifests must be a non-empty unique list")
    elif roster != sorted(roster):
        errors.append("input_manifests must be lexicographically ordered")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
    ids: set[str] = set()
    timestamps: set[str] = set()
    summary_digests: set[str] = set()
    input_digests: set[str] = set()
    canonicalizations: set[str] = set()
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
        timestamp = record.get("timestamp_utc")
        if not _text(timestamp):
            errors.append(f"{prefix}.timestamp_utc is required")
        elif timestamp in timestamps:
            errors.append(f"{prefix}.timestamp_utc is duplicated")
        else:
            timestamps.add(timestamp)
        if record.get("input_manifests") != roster:
            errors.append(f"{prefix}.input_manifests must match ordered roster")
        digest = record.get("summary_sha256")
        if not _digest(digest):
            errors.append(f"{prefix}.summary_sha256 must be a lowercase 64-character digest")
        else:
            summary_digests.add(digest)
        digest = record.get("input_sha256")
        if not _digest(digest):
            errors.append(f"{prefix}.input_sha256 must be a lowercase 64-character digest")
        else:
            input_digests.add(digest)
        canonical = record.get("canonicalization")
        if not _text(canonical):
            errors.append(f"{prefix}.canonicalization is required")
        else:
            canonicalizations.add(canonical)
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("independent") is not True:
            errors.append(f"{prefix}.independent must be true")
    if len(summary_digests) > 1:
        errors.append("records.summary_sha256 digests must agree")
    if len(input_digests) > 1:
        errors.append("records.input_sha256 digests must agree")
    if canonicalizations != {summary.get("canonicalization")}:
        errors.append("records canonicalization must match summary canonicalization")
    if summary_digests and summary.get("consensus_summary_sha256") not in summary_digests:
        errors.append("consensus_summary_sha256 must match records")
    if input_digests and summary.get("consensus_input_sha256") not in input_digests:
        errors.append("consensus_input_sha256 must match records")
    if summary.get("consensus") is not True:
        errors.append("consensus must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_DIGEST_REPRO_V5_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_DIGEST_REPRO_V5_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
