#!/usr/bin/env python3
"""Validate recorded manifest digest and entry-count consistency."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


def _status(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    state = record.get("status")
    if state not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if state == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_rollup(value: Any, label: str = "rollup") -> list[str]:
    """Return violations; an empty list means the digest/count rollup is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "manifest_path", "manifest_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(value.get("manifest_sha256")) and not _digest(value["manifest_sha256"]):
        errors.append(f"{label}.manifest_sha256 must be a 64-character hex digest")
    entries = value.get("entry_count")
    if not isinstance(entries, int) or entries <= 0:
        errors.append(f"{label}.entry_count must be positive")
    observed = value.get("observed_entry_count")
    if not isinstance(observed, int) or observed < 0:
        errors.append(f"{label}.observed_entry_count must be a non-negative integer")
    if isinstance(entries, int) and isinstance(observed, int) and entries != observed:
        errors.append(f"{label}.entry_count must equal observed_entry_count")

    digest = value.get("digest_check")
    _status(digest, f"{label}.digest_check", errors)
    if isinstance(digest, dict) and digest.get("status") == "PASS":
        if digest.get("computed_sha256") != value.get("manifest_sha256"):
            errors.append(f"{label}.digest_check.computed_sha256 must match manifest_sha256")
        if not _digest(digest.get("computed_sha256")):
            errors.append(f"{label}.digest_check.computed_sha256 must be a 64-character hex digest")

    count = value.get("count_check")
    _status(count, f"{label}.count_check", errors)
    if isinstance(count, dict) and count.get("status") == "PASS" and count.get("matches") is not True:
        errors.append(f"{label}.count_check.matches must be true when status is PASS")

    native = value.get("native_execution")
    _status(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is {native['status']}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_rollup(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("MANIFEST_DIGEST_COUNT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MANIFEST_DIGEST_COUNT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
