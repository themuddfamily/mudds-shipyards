#!/usr/bin/env python3
"""Validate explicit source/hash audit decisions and their rationale."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
SCHEMA_VERSION = 1


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _decision(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    status = record.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    evidence = record.get("evidence")
    if status == "PASS" and not _text(evidence):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"FAIL", "UNKNOWN"} and not _text(record.get("reason")):
        errors.append(f"{label}.reason is required when status is {status}")
    if status == "NOT_RUN" and evidence is not None:
        errors.append(f"{label}.evidence must be null when status is NOT_RUN")


def validate_flags(value: Any, label: str = "flags") -> list[str]:
    """Return violations; an empty list means audit decisions are valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    source = value.get("source_audit")
    _decision(source, f"{label}.source_audit", errors)
    artifact = value.get("artifact_audit")
    _decision(artifact, f"{label}.artifact_audit", errors)
    binding = value.get("binding_audit")
    _decision(binding, f"{label}.binding_audit", errors)
    if all(isinstance(item, dict) and item.get("status") == "PASS" for item in (source, artifact, binding)):
        if value.get("overall_pass") is not True:
            errors.append(f"{label}.overall_pass must be true when all audits PASS")
    if value.get("overall_pass") is True and any(isinstance(item, dict) and item.get("status") != "PASS" for item in (source, artifact, binding)):
        errors.append(f"{label}.overall_pass requires every audit to PASS")
    native = value.get("native_execution")
    _decision(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") == "NOT_RUN":
        for key in ("platform", "hardware", "evidence_path", "reason"):
            if key != "reason" and native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is NOT_RUN")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_flags(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_AUDIT_FLAGS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_AUDIT_FLAGS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
