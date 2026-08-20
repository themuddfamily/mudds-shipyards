#!/usr/bin/env python3
"""Validate reproducible digest metadata for an audio cleanup summary."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_summary_digest_v1"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _unique_texts(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_digest(record: Any) -> list[str]:
    if not isinstance(record, dict):
        return ["record must be an object"]
    errors: list[str] = []
    if record.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "digest_owner", "summary_path", "digest_evidence"):
        if not _text(record.get(key)):
            errors.append(f"{key} is required")
    if record.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if record.get("claim") != "AUTOMATED_DIGEST_ONLY":
        errors.append("claim must be AUTOMATED_DIGEST_ONLY")
    if not _text(record.get("boundary_note")):
        errors.append("boundary_note is required")
    if record.get("algorithm") != "SHA-256":
        errors.append("algorithm must be SHA-256")
    digest = record.get("summary_sha256")
    if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
        errors.append("summary_sha256 must be a lowercase 64-character digest")
    inputs = record.get("input_manifests")
    if not _unique_texts(inputs):
        errors.append("input_manifests must be a non-empty unique list of paths")
    if _unique_texts(inputs) and record.get("input_count") != len(inputs):
        errors.append("input_count must match input_manifests length")
    if not isinstance(record.get("input_count"), int) or isinstance(record.get("input_count"), bool) or record.get("input_count", 0) <= 0:
        errors.append("input_count must be a positive integer")
    if not _text(record.get("canonicalization")):
        errors.append("canonicalization is required")
    if record.get("reproducible") is not True:
        errors.append("reproducible must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_digest(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_SUMMARY_DIGEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_SUMMARY_DIGEST_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
