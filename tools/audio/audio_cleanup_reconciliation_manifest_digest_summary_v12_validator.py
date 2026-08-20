#!/usr/bin/env python3
"""Validate v12 cleanup reconciliation manifest digest summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_reconciliation_manifest_digest_summary_v12"
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
    if summary.get("claim") != "AUTOMATED_RECONCILIATION_MANIFEST_ONLY":
        errors.append("claim must be AUTOMATED_RECONCILIATION_MANIFEST_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if not _digest(summary.get("reconciliation_digest")):
        errors.append("reconciliation_digest must be a lowercase 64-character digest")

    manifests = summary.get("manifests")
    if not isinstance(manifests, list) or not manifests:
        errors.append("manifests must be a non-empty array")
        manifests = []
    paths: list[str] = []
    entry_digests: set[str] = set()
    for index, manifest in enumerate(manifests):
        prefix = f"manifests[{index}]"
        if not isinstance(manifest, dict):
            errors.append(f"{prefix} must be an object")
            continue
        path = manifest.get("path")
        if not _text(path):
            errors.append(f"{prefix}.path is required")
        else:
            paths.append(path)
        digest = manifest.get("sha256")
        if not _digest(digest):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")
        else:
            entry_digests.add(digest)
        if manifest.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(manifest.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
    if paths != sorted(paths):
        errors.append("manifests paths must be lexicographically ordered")
    if len(paths) != len(set(paths)):
        errors.append("manifests paths must be unique")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
    record_digests: set[str] = set()
    record_ids: set[str] = set()
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
        digest = record.get("reconciliation_digest")
        if not _digest(digest):
            errors.append(f"{prefix}.reconciliation_digest must be a lowercase 64-character digest")
        else:
            record_digests.add(digest)
        if record.get("manifest_paths") != paths:
            errors.append(f"{prefix}.manifest_paths must match ordered manifest paths")
        if record.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
    if len(record_digests) > 1:
        errors.append("records reconciliation_digest values must agree")
    if record_digests and summary.get("reconciliation_digest") not in record_digests:
        errors.append("reconciliation_digest must match records")
    if summary.get("reconciliation_pass") is not True:
        errors.append("reconciliation_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_RECONCILIATION_MANIFEST_V12_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_RECONCILIATION_MANIFEST_V12_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
