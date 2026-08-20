#!/usr/bin/env python3
"""Validate recorded package manifest entries against one source commit."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _status(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    status = record.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if status == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_alignment(value: Any, label: str = "alignment") -> list[str]:
    """Return violations; an empty list means the manifest alignment is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    commit = value.get("source_commit")
    for key in ("build_label", "source_commit", "manifest_path"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    manifest = value.get("manifest")
    _status(manifest, f"{label}.manifest", errors)
    if isinstance(manifest, dict) and manifest.get("status") == "PASS":
        if manifest.get("source_commit") != commit:
            errors.append(f"{label}.manifest.source_commit must match source_commit")
        if not isinstance(manifest.get("entry_count"), int) or manifest["entry_count"] <= 0:
            errors.append(f"{label}.manifest.entry_count must be positive when status is PASS")

    entries = value.get("entries")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.entries must be a non-empty list")
        entries = []
    paths: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        path = entry.get("path")
        if not _text(path):
            errors.append(f"{prefix}.path is required")
        elif path in paths:
            errors.append(f"{prefix}.path must be unique")
        else:
            paths.add(path)
        if entry.get("source_commit") != commit:
            errors.append(f"{prefix}.source_commit must match source_commit")
    if isinstance(manifest, dict) and manifest.get("status") == "PASS" and isinstance(manifest.get("entry_count"), int) and manifest["entry_count"] != len(entries):
        errors.append(f"{label}.manifest.entry_count must equal entries count")

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
    errors = validate_alignment(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("MANIFEST_SOURCE_ALIGNMENT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MANIFEST_SOURCE_ALIGNMENT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
