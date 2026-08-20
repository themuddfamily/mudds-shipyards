#!/usr/bin/env python3
"""Validate v13 cleanup manifest identity consensus summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_manifest_identity_consensus_summary_v13"
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
    if summary.get("claim") != "AUTOMATED_MANIFEST_IDENTITY_ONLY":
        errors.append("claim must be AUTOMATED_MANIFEST_IDENTITY_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    roster = summary.get("manifest_ids")
    if not _ordered_unique(roster):
        errors.append("manifest_ids must be ordered, unique, and non-empty")

    manifests = summary.get("manifests")
    manifest_ids: set[str] = set()
    manifest_digests: set[str] = set()
    if not isinstance(manifests, list) or not manifests:
        errors.append("manifests must be a non-empty array")
        manifests = []
    for index, manifest in enumerate(manifests):
        prefix = f"manifests[{index}]"
        if not isinstance(manifest, dict):
            errors.append(f"{prefix} must be an object")
            continue
        manifest_id = manifest.get("manifest_id")
        if not _text(manifest_id):
            errors.append(f"{prefix}.manifest_id is required")
        elif manifest_id in manifest_ids:
            errors.append(f"{prefix}.manifest_id is duplicated")
        else:
            manifest_ids.add(manifest_id)
        if manifest.get("manifest_id") not in (roster if isinstance(roster, list) else []):
            errors.append(f"{prefix}.manifest_id must be in manifest_ids")
        digest = manifest.get("sha256")
        if not _digest(digest):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")
        else:
            manifest_digests.add(digest)
        if not _text(manifest.get("path")):
            errors.append(f"{prefix}.path is required")
        if manifest.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
    if (set(roster) if isinstance(roster, list) else set()) != manifest_ids:
        errors.append("manifest_ids must exactly match manifest entries")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
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
        if record.get("manifest_ids") != roster:
            errors.append(f"{prefix}.manifest_ids must match ordered summary roster")
        record_digest = record.get("manifest_set_sha256")
        if not _digest(record_digest):
            errors.append(f"{prefix}.manifest_set_sha256 must be a lowercase 64-character digest")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("identity_pass") is not True:
            errors.append(f"{prefix}.identity_pass must be true")
    if summary.get("identity_pass") is not True:
        errors.append("identity_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_MANIFEST_IDENTITY_V13_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_MANIFEST_IDENTITY_V13_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
