#!/usr/bin/env python3
"""Validate v4 cleanup-digest reproducibility summaries and input ordering."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_reproducibility_summary_v4"
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
    if summary.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if summary.get("claim") != "AUTOMATED_REPRODUCIBILITY_V4_ONLY":
        errors.append("claim must be AUTOMATED_REPRODUCIBILITY_V4_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if summary.get("algorithm") != "SHA-256":
        errors.append("algorithm must be SHA-256")
    if not _digest(summary.get("summary_sha256")):
        errors.append("summary_sha256 must be a lowercase 64-character digest")
    inputs = summary.get("input_manifests")
    if not _paths(inputs):
        errors.append("input_manifests must be a non-empty unique list")
    elif inputs != sorted(inputs):
        errors.append("input_manifests must be lexicographically ordered")

    runs = summary.get("runs")
    if not isinstance(runs, list) or len(runs) < 2:
        errors.append("runs must contain at least two rows")
        runs = []
    ids: set[str] = set()
    timestamps: set[str] = set()
    digests: set[str] = set()
    for index, run in enumerate(runs):
        prefix = f"runs[{index}]"
        if not isinstance(run, dict):
            errors.append(f"{prefix} must be an object")
            continue
        run_id = run.get("run_id")
        if not _text(run_id):
            errors.append(f"{prefix}.run_id is required")
        elif run_id in ids:
            errors.append(f"{prefix}.run_id is duplicated")
        else:
            ids.add(run_id)
        timestamp = run.get("timestamp_utc")
        if not _text(timestamp):
            errors.append(f"{prefix}.timestamp_utc is required")
        elif timestamp in timestamps:
            errors.append(f"{prefix}.timestamp_utc is duplicated")
        else:
            timestamps.add(timestamp)
        if run.get("input_manifests") != inputs:
            errors.append(f"{prefix}.input_manifests must match ordered summary roster")
        digest = run.get("summary_sha256")
        if not _digest(digest):
            errors.append(f"{prefix}.summary_sha256 must be a lowercase 64-character digest")
        else:
            digests.add(digest)
        if run.get("canonicalization") != summary.get("canonicalization"):
            errors.append(f"{prefix}.canonicalization must match summary canonicalization")
        if not _text(run.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if run.get("independent") is not True:
            errors.append(f"{prefix}.independent must be true")
    if len(digests) > 1:
        errors.append("runs.summary_sha256 digests must agree")
    if digests and summary.get("summary_sha256") not in digests:
        errors.append("summary_sha256 must match per-run summary_sha256")
    if summary.get("reproducible") is not True:
        errors.append("reproducible must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_DIGEST_REPRO_V4_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_DIGEST_REPRO_V4_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
