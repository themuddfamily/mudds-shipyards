#!/usr/bin/env python3
"""Validate version-59 source-hash source/channel/release evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 59
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


def validate_v59(value: Any, label: str = "source_channel_release_v59") -> list[str]:
    """Return violations; an empty list means source/channel/release evidence is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_id", "source_ref", "channel_id", "release_id", "release_channel", "source_commit", "source_hash", "source_version", "package_version"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    attestation = value.get("source_attestation")
    _status(attestation, f"{label}.source_attestation", errors)
    if isinstance(attestation, dict) and attestation.get("status") == "PASS":
        for key in ("source_id", "source_ref", "channel_id", "release_id", "release_channel", "source_commit", "source_hash", "source_version", "package_version"):
            if attestation.get(key) != value.get(key):
                errors.append(f"{label}.source_attestation.{key} must match {key}")
        if attestation.get("attested") is not True:
            errors.append(f"{label}.source_attestation.attested must be true when status is PASS")

    native = value.get("native_execution")
    _status(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") == "NOT_RUN":
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is NOT_RUN")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_v59(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_SOURCE_CHANNEL_RELEASE_V59_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_SOURCE_CHANNEL_RELEASE_V59_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
