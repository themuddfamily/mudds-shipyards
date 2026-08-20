#!/usr/bin/env python3
"""Validate recorded PE/PCK metadata without inspecting a package on disk."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


def _status(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    status = record.get("status")
    if status not in STATUSES:
        errors.append(f"{label}.status is invalid")
        return
    if status == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_metadata(value: Any, label: str = "metadata") -> list[str]:
    """Return violations; an empty list means the recorded metadata is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_path"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("artifact_sha256") is not None and not _digest(value.get("artifact_sha256")):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest when provided")

    pe = value.get("pe")
    _status(pe, f"{label}.pe", errors)
    if isinstance(pe, dict) and pe.get("status") == "PASS":
        for key in ("machine", "file_version", "section_count"):
            if key not in pe:
                errors.append(f"{label}.pe.{key} is required when status is PASS")
        if not _text(pe.get("machine")):
            errors.append(f"{label}.pe.machine must be non-empty text")
        if not _text(pe.get("file_version")):
            errors.append(f"{label}.pe.file_version must be non-empty text")
        if not isinstance(pe.get("section_count"), int) or pe["section_count"] <= 0:
            errors.append(f"{label}.pe.section_count must be a positive integer")

    pck = value.get("pck")
    _status(pck, f"{label}.pck", errors)
    if isinstance(pck, dict) and pck.get("status") == "PASS":
        for key in ("format", "entry_count", "manifest_sha256", "embedded_offset"):
            if key not in pck:
                errors.append(f"{label}.pck.{key} is required when status is PASS")
        if pck.get("format") != 4:
            errors.append(f"{label}.pck.format must be 4 when status is PASS")
        if not isinstance(pck.get("entry_count"), int) or pck["entry_count"] <= 0:
            errors.append(f"{label}.pck.entry_count must be a positive integer")
        if not _digest(pck.get("manifest_sha256")):
            errors.append(f"{label}.pck.manifest_sha256 must be a 64-character hex digest")
        if not isinstance(pck.get("embedded_offset"), int) or pck["embedded_offset"] < 0:
            errors.append(f"{label}.pck.embedded_offset must be a non-negative integer")
    if isinstance(pe, dict) and isinstance(pck, dict) and pe.get("status") == "PASS" and pck.get("status") == "PASS":
        if pck.get("external") is True:
            errors.append(f"{label}.pck.external must be false for embedded package metadata")

    native = value.get("native_inspection")
    _status(native, f"{label}.native_inspection", errors)
    if isinstance(native, dict) and native.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_inspection.{key} must be null when status is {native['status']}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_metadata(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("PE_PCK_METADATA_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PE_PCK_METADATA_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
