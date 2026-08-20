#!/usr/bin/env python3
"""Validate v18 cleanup manifest completeness and authority boundaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_manifest_completeness_authority_summary_v18"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_EXCLUSIONS = {"gameplay_damage", "gameplay_phase", "reward"}


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
    if summary.get("claim") != "AUTOMATED_COMPLETENESS_AUTHORITY_ONLY":
        errors.append("claim must be AUTOMATED_COMPLETENESS_AUTHORITY_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    ids = summary.get("manifest_ids")
    if not _ordered_unique(ids):
        errors.append("manifest_ids must be ordered, unique, and non-empty")

    entries = summary.get("entries")
    entry_ids: set[str] = set()
    if not isinstance(entries, list) or not entries:
        errors.append("entries must be a non-empty array")
        entries = []
    for index, entry in enumerate(entries):
        prefix = f"entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        entry_id = entry.get("manifest_id")
        if not _text(entry_id):
            errors.append(f"{prefix}.manifest_id is required")
        elif entry_id in entry_ids:
            errors.append(f"{prefix}.manifest_id is duplicated")
        else:
            entry_ids.add(entry_id)
        if isinstance(ids, list) and entry_id not in ids:
            errors.append(f"{prefix}.manifest_id must be in manifest_ids")
        if not _digest(entry.get("sha256")):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")
        if entry.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if entry.get("authority") != "presentation_only":
            errors.append(f"{prefix}.authority must be presentation_only")
        exclusions = entry.get("authority_exclusions")
        if not isinstance(exclusions, list) or any(not _text(item) for item in exclusions):
            errors.append(f"{prefix}.authority_exclusions must be a list of strings")
        elif not REQUIRED_EXCLUSIONS.issubset(exclusions):
            errors.append(f"{prefix}.authority_exclusions must include gameplay_damage, gameplay_phase, and reward")
        if not _text(entry.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if entry.get("complete") is not True:
            errors.append(f"{prefix}.complete must be true")
    if isinstance(ids, list) and entry_ids != set(ids):
        errors.append("entries must exactly cover manifest_ids")
    if summary.get("completeness_authority_pass") is not True:
        errors.append("completeness_authority_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_COMPLETENESS_AUTHORITY_V18_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_COMPLETENESS_AUTHORITY_V18_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
