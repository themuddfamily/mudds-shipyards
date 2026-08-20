#!/usr/bin/env python3
"""Validate uniqueness and identity of a recorded package release manifest."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
SCHEMA_VERSION = 1


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


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


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    """Return violations; an empty list means the release manifest is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    source_commit = value.get("source_commit")
    if not _text(source_commit):
        errors.append(f"{label}.source_commit is required")
    entries = value.get("releases")
    if not isinstance(entries, list) or not entries:
        errors.append(f"{label}.releases must be a non-empty list")
        entries = []
    labels: set[str] = set()
    paths: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"{label}.releases[{index}]"
        _status(entry, prefix, errors)
        if not isinstance(entry, dict):
            continue
        for key in ("release_label", "artifact_path", "source_commit"):
            if not _text(entry.get(key)):
                errors.append(f"{prefix}.{key} is required")
        release_label = entry.get("release_label")
        if _text(release_label):
            if release_label in labels:
                errors.append(f"{prefix}.release_label must be unique")
            labels.add(release_label)
        path = entry.get("artifact_path")
        if _text(path):
            if path in paths:
                errors.append(f"{prefix}.artifact_path must be unique")
            paths.add(path)
        if _text(source_commit) and entry.get("source_commit") != source_commit:
            errors.append(f"{prefix}.source_commit must match manifest.source_commit")
        if entry.get("status") == "PASS" and entry.get("artifact_hash_recorded") is not True:
            errors.append(f"{prefix}.artifact_hash_recorded must be true when status is PASS")

    audit = value.get("uniqueness_audit")
    _status(audit, f"{label}.uniqueness_audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS" and audit.get("duplicates") != 0:
        errors.append(f"{label}.uniqueness_audit.duplicates must be 0 when status is PASS")

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
    errors = validate_manifest(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("RELEASE_MANIFEST_UNIQUENESS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("RELEASE_MANIFEST_UNIQUENESS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
