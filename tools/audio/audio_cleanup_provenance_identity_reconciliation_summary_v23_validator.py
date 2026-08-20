#!/usr/bin/env python3
"""Validate v23 cleanup provenance identity reconciliation summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_provenance_identity_reconciliation_summary_v23"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
STATUSES = {"project_original", "licensed", "permission_recorded"}


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
    if summary.get("claim") != "AUTOMATED_PROVENANCE_IDENTITY_ONLY":
        errors.append("claim must be AUTOMATED_PROVENANCE_IDENTITY_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    identities = summary.get("identities")
    identity_ids: set[str] = set()
    if not isinstance(identities, list) or not identities:
        errors.append("identities must be a non-empty array")
        identities = []
    for index, identity in enumerate(identities):
        prefix = f"identities[{index}]"
        if not isinstance(identity, dict):
            errors.append(f"{prefix} must be an object")
            continue
        identity_id = identity.get("identity_id")
        if not _text(identity_id):
            errors.append(f"{prefix}.identity_id is required")
        elif identity_id in identity_ids:
            errors.append(f"{prefix}.identity_id is duplicated")
        else:
            identity_ids.add(identity_id)
        for key in ("asset_id", "source_id", "source", "license", "evidence"):
            if not _text(identity.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if identity.get("status") not in STATUSES:
            errors.append(f"{prefix}.status is invalid")
        if not _digest(identity.get("digest")):
            errors.append(f"{prefix}.digest must be a lowercase 64-character digest")
        if identity.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if identity.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")

    records = summary.get("records")
    if not isinstance(records, list) or len(records) < 2:
        errors.append("records must contain at least two rows")
        records = []
    record_ids: set[str] = set()
    record_identity_sets: list[set[str]] = []
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
        roster = record.get("identity_ids")
        if not isinstance(roster, list) or any(not _text(item) for item in roster) or len(roster) != len(set(roster)):
            errors.append(f"{prefix}.identity_ids must be a unique list")
        else:
            record_identity_sets.append(set(roster))
            if set(roster) != identity_ids:
                errors.append(f"{prefix}.identity_ids must match identities")
        digest = record.get("provenance_digest")
        if not _digest(digest):
            errors.append(f"{prefix}.provenance_digest must be a lowercase 64-character digest")
        else:
            record_digests.add(digest)
        if record.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("identity_pass") is not True:
            errors.append(f"{prefix}.identity_pass must be true")
    if len(record_digests) > 1:
        errors.append("records provenance_digest values must agree")
    if summary.get("identity_reconciliation_pass") is not True:
        errors.append("identity_reconciliation_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_PROVENANCE_IDENTITY_V23_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_PROVENANCE_IDENTITY_V23_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
