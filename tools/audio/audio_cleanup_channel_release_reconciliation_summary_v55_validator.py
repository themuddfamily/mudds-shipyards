#!/usr/bin/env python3
"""Validate v55 channel/release reconciliation summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "audio_cleanup_channel_release_reconciliation_summary_v55"
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
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization", "channel_id", "release_id", "reconciliation_id", "release_version"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_CHANNEL_RELEASE_RECONCILIATION_ONLY":
        errors.append("claim must be AUTOMATED_CHANNEL_RELEASE_RECONCILIATION_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids = summary.get("record_ids")
    if not _roster(ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    if not _roster(summary.get("release_versions")):
        errors.append("release_versions must be ordered, unique, and non-empty")
    if _text(summary.get("release_version")) and isinstance(summary.get("release_versions"), list) and summary["release_version"] not in summary["release_versions"]:
        errors.append("release_version must be in release_versions")
    for key in ("channel_digest", "release_digest", "reconciliation_digest"):
        if not _digest(summary.get(key)):
            errors.append(f"{key} must be a lowercase 64-character digest")
    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
        records = []
    seen: set[str] = set()
    triples: set[tuple[str, str, str]] = set()
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
        keys = ("channel_digest", "release_digest", "reconciliation_digest")
        for key in keys:
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
            elif record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if all(_digest(record.get(key)) for key in keys):
            triples.add(tuple(record[key] for key in keys))
        for key in ("channel_id", "release_id", "reconciliation_id", "release_version", "canonicalization"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("channel_pass") is not True:
            errors.append(f"{prefix}.channel_pass must be true")
    if isinstance(ids, list) and seen != set(ids):
        errors.append("record_ids must exactly match records")
    if len(triples) > 1:
        errors.append("records channel/release/reconciliation triples must agree")
    if summary.get("channel_reconciliation_pass") is not True:
        errors.append("channel_reconciliation_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_CHANNEL_RELEASE_RECONCILIATION_V55_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_CHANNEL_RELEASE_RECONCILIATION_V55_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
