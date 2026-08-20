#!/usr/bin/env python3
"""Validate v34 schema-versioned root/authority digest summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "audio_cleanup_schema_version_root_authority_digest_v34"
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
    required = ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization", "root_id", "authority_id", "schema_version")
    for key in required:
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_SCHEMA_VERSION_ROOT_AUTHORITY_DIGEST_ONLY":
        errors.append("claim must be AUTOMATED_SCHEMA_VERSION_ROOT_AUTHORITY_DIGEST_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids, versions = summary.get("record_ids"), summary.get("schema_versions")
    if not _ordered_unique(ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    if not _ordered_unique(versions):
        errors.append("schema_versions must be ordered, unique, and non-empty")
    if _text(summary.get("schema_version")) and isinstance(versions, list) and summary["schema_version"] not in versions:
        errors.append("schema_version must be in schema_versions")
    digest_keys = ("root_summary_digest", "root_reconciliation_digest", "authority_summary_digest", "authority_reconciliation_digest")
    for key in digest_keys:
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
        if isinstance(ids, list) and rid not in ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        for key in ("summary_digest", "reconciliation_digest", "authority_summary_digest", "authority_reconciliation_digest"):
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
        if all(_digest(record.get(key)) for key in ("summary_digest", "reconciliation_digest", "authority_summary_digest", "authority_reconciliation_digest")):
            pairs.add(tuple(record[key] for key in ("summary_digest", "reconciliation_digest", "authority_summary_digest", "authority_reconciliation_digest")))
        for key in ("root_id", "authority_id", "schema_version"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        for key in ("authority_summary_digest", "authority_reconciliation_digest"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("schema_pass") is not True:
            errors.append(f"{prefix}.schema_pass must be true")
    if isinstance(ids, list) and seen != set(ids):
        errors.append("record_ids must exactly match records")
    roots = [r for r in records if isinstance(r, dict) and r.get("record_id") == summary.get("root_id")]
    if not roots:
        errors.append("root_id must reference a record")
    elif roots[0].get("summary_digest") != summary.get("root_summary_digest"):
        errors.append("root_summary_digest must match root record")
    if len(pairs) > 1:
        errors.append("records schema digest pairs must agree")
    if summary.get("schema_digest_pass") is not True:
        errors.append("schema_digest_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_SCHEMA_VERSION_ROOT_AUTHORITY_DIGEST_V34_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_SCHEMA_VERSION_ROOT_AUTHORITY_DIGEST_V34_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
