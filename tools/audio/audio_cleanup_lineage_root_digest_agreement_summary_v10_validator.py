#!/usr/bin/env python3
"""Validate v10 cross-record cleanup-lineage root digest agreement."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_lineage_root_digest_agreement_summary_v10"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_ROOT_AGREEMENT_ONLY":
        errors.append("claim must be AUTOMATED_ROOT_AGREEMENT_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if not _digest(summary.get("agreed_root_digest")):
        errors.append("agreed_root_digest must be a lowercase 64-character digest")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
    ids: set[str] = set()
    roots: set[str] = set()
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
        root = record.get("root_digest")
        if not _digest(root):
            errors.append(f"{prefix}.root_digest must be a lowercase 64-character digest")
        else:
            roots.add(root)
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("root_evidence")):
            errors.append(f"{prefix}.root_evidence is required")
        if record.get("root_verified") is not True:
            errors.append(f"{prefix}.root_verified must be true")
    if len(roots) > 1:
        errors.append("records root_digest values must agree")
    if roots and summary.get("agreed_root_digest") not in roots:
        errors.append("agreed_root_digest must match records")
    if summary.get("agreement_pass") is not True:
        errors.append("agreement_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_ROOT_AGREEMENT_V10_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_ROOT_AGREEMENT_V10_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
