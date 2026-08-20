#!/usr/bin/env python3
"""Validate v3 cleanup-digest reproducibility metadata and canonicalization."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_reproducibility_summary_v3"
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
    if summary.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if summary.get("claim") != "AUTOMATED_REPRODUCIBILITY_V3_ONLY":
        errors.append("claim must be AUTOMATED_REPRODUCIBILITY_V3_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if summary.get("algorithm") != "SHA-256":
        errors.append("algorithm must be SHA-256")
    if not _digest(summary.get("summary_sha256")):
        errors.append("summary_sha256 must be a lowercase 64-character digest")

    runs = summary.get("runs")
    if not isinstance(runs, list) or len(runs) < 2:
        errors.append("runs must contain at least two rows")
        runs = []
    seen_ids: set[str] = set()
    digests: set[str] = set()
    canonicalizations: set[str] = set()
    tool_versions: set[str] = set()
    for index, run in enumerate(runs):
        prefix = f"runs[{index}]"
        if not isinstance(run, dict):
            errors.append(f"{prefix} must be an object")
            continue
        run_id = run.get("run_id")
        if not _text(run_id):
            errors.append(f"{prefix}.run_id is required")
        elif run_id in seen_ids:
            errors.append(f"{prefix}.run_id is duplicated")
        else:
            seen_ids.add(run_id)
        digest = run.get("summary_sha256")
        if not _digest(digest):
            errors.append(f"{prefix}.summary_sha256 must be a lowercase 64-character digest")
        else:
            digests.add(digest)
        for key, values in (("canonicalization", canonicalizations), ("tool_version", tool_versions)):
            if not _text(run.get(key)):
                errors.append(f"{prefix}.{key} is required")
            else:
                values.add(run[key])
        if not _text(run.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if run.get("independent") is not True:
            errors.append(f"{prefix}.independent must be true")
    if len(digests) > 1:
        errors.append("runs.summary_sha256 digests must agree")
    if canonicalizations and canonicalizations != {summary.get("canonicalization")}:
        errors.append("runs canonicalization must match summary canonicalization")
    if len(tool_versions) > 1:
        errors.append("runs tool_version values must agree")
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
        print("AUDIO_CLEANUP_DIGEST_REPRO_V3_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_DIGEST_REPRO_V3_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
