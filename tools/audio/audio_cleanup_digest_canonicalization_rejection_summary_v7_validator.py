#!/usr/bin/env python3
"""Validate v7 cleanup-digest canonicalization rejection summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_canonicalization_rejection_summary_v7"
CANONICALIZATION = "json-sorted-v1"
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
    for key in ("revision", "owner", "summary_id", "evidence_bundle"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_CANONICALIZATION_REJECTION_ONLY":
        errors.append("claim must be AUTOMATED_CANONICALIZATION_REJECTION_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if summary.get("accepted_canonicalization") != CANONICALIZATION:
        errors.append(f"accepted_canonicalization must be {CANONICALIZATION}")
    if not _digest(summary.get("accepted_digest")):
        errors.append("accepted_digest must be a lowercase 64-character digest")

    accepted = summary.get("accepted")
    if not isinstance(accepted, dict):
        errors.append("accepted must be an object")
        accepted = {}
    if accepted.get("canonicalization") != CANONICALIZATION:
        errors.append(f"accepted.canonicalization must be {CANONICALIZATION}")
    if accepted.get("digest") != summary.get("accepted_digest"):
        errors.append("accepted.digest must match accepted_digest")
    if accepted.get("rejected") is not False:
        errors.append("accepted.rejected must be false")
    if not _text(accepted.get("evidence")):
        errors.append("accepted.evidence is required")

    rejected = summary.get("rejected")
    if not isinstance(rejected, list) or not rejected:
        errors.append("rejected must be a non-empty array")
        rejected = []
    rejection_ids: set[str] = set()
    for index, row in enumerate(rejected):
        prefix = f"rejected[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        rejection_id = row.get("rejection_id")
        if not _text(rejection_id):
            errors.append(f"{prefix}.rejection_id is required")
        elif rejection_id in rejection_ids:
            errors.append(f"{prefix}.rejection_id is duplicated")
        else:
            rejection_ids.add(rejection_id)
        if row.get("canonicalization") == CANONICALIZATION:
            errors.append(f"{prefix}.canonicalization must be rejected as non-accepted")
        if not _text(row.get("canonicalization")):
            errors.append(f"{prefix}.canonicalization is required")
        if not _digest(row.get("digest")):
            errors.append(f"{prefix}.digest must be a lowercase 64-character digest")
        if row.get("rejected") is not True:
            errors.append(f"{prefix}.rejected must be true")
        if not _text(row.get("reason")):
            errors.append(f"{prefix}.reason is required")
        if not _text(row.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
    if summary.get("rejection_count") != len(rejected):
        errors.append("rejection_count must match rejected length")
    if summary.get("rejection_pass") is not True:
        errors.append("rejection_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_CANONICALIZATION_REJECTION_V7_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_CANONICALIZATION_REJECTION_V7_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
