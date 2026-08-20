#!/usr/bin/env python3
"""Validate independent reproducibility runs for an audio cleanup digest."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_reproducibility_v1"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _paths(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_reproducibility(record: Any) -> list[str]:
    if not isinstance(record, dict):
        return ["record must be an object"]
    errors: list[str] = []
    if record.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle"):
        if not _text(record.get(key)):
            errors.append(f"{key} is required")
    if record.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if record.get("claim") != "AUTOMATED_REPRODUCIBILITY_ONLY":
        errors.append("claim must be AUTOMATED_REPRODUCIBILITY_ONLY")
    if not _text(record.get("boundary_note")):
        errors.append("boundary_note is required")
    if record.get("algorithm") != "SHA-256":
        errors.append("algorithm must be SHA-256")
    inputs = record.get("input_manifests")
    if not _paths(inputs):
        errors.append("input_manifests must be a non-empty unique list")

    runs = record.get("runs")
    if not isinstance(runs, list) or len(runs) < 2:
        errors.append("runs must contain at least two independent runs")
        runs = []
    run_ids: set[str] = set()
    digests: list[str] = []
    for index, run in enumerate(runs):
        prefix = f"runs[{index}]"
        if not isinstance(run, dict):
            errors.append(f"{prefix} must be an object")
            continue
        run_id = run.get("run_id")
        if not _text(run_id):
            errors.append(f"{prefix}.run_id is required")
        elif run_id in run_ids:
            errors.append(f"{prefix}.run_id is duplicated")
        else:
            run_ids.add(run_id)
        digest = run.get("sha256")
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")
        else:
            digests.append(digest)
        if run.get("input_manifests") != inputs:
            errors.append(f"{prefix}.input_manifests must match record input_manifests")
        if not _text(run.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if run.get("independent") is not True:
            errors.append(f"{prefix}.independent must be true")
    if len(digests) >= 2 and len(set(digests)) != 1:
        errors.append("runs sha256 digests must match")
    if not isinstance(record.get("reproducible"), bool):
        errors.append("reproducible must be boolean")
    elif record["reproducible"] is not (len(digests) >= 2 and len(set(digests)) == 1 and len(runs) >= 2):
        errors.append("reproducible does not match run digest agreement")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_reproducibility(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_DIGEST_REPRODUCIBILITY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_DIGEST_REPRODUCIBILITY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
