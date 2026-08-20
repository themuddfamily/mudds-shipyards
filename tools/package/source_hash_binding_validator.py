#!/usr/bin/env python3
"""Validate source-commit and artifact-hash binding from recorded evidence."""

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
    status = record.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if status == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_binding(value: Any, label: str = "binding") -> list[str]:
    """Return violations; an empty list means source/hash binding is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    source_commit = value.get("source_commit")
    artifact_hash = value.get("artifact_sha256")
    for key in ("build_label", "source_commit", "artifact_path", "artifact_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if _text(artifact_hash) and not _digest(artifact_hash):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest")

    build = value.get("build_record")
    _status(build, f"{label}.build_record", errors)
    if isinstance(build, dict) and build.get("status") == "PASS":
        if build.get("source_commit") != source_commit:
            errors.append(f"{label}.build_record.source_commit must match source_commit")
        if build.get("artifact_sha256") != artifact_hash:
            errors.append(f"{label}.build_record.artifact_sha256 must match artifact_sha256")

    manifest = value.get("manifest_record")
    _status(manifest, f"{label}.manifest_record", errors)
    if isinstance(manifest, dict) and manifest.get("status") == "PASS":
        if manifest.get("source_commit") != source_commit:
            errors.append(f"{label}.manifest_record.source_commit must match source_commit")
        if manifest.get("artifact_sha256") != artifact_hash:
            errors.append(f"{label}.manifest_record.artifact_sha256 must match artifact_sha256")

    audit = value.get("binding_audit")
    _status(audit, f"{label}.binding_audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS":
        if audit.get("commit_match") is not True or audit.get("hash_match") is not True:
            errors.append(f"{label}.binding_audit commit_match and hash_match must be true when status is PASS")

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
    errors = validate_binding(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_BINDING_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_BINDING_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
