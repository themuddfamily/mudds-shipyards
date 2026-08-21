#!/usr/bin/env python3
"""Validate version-282 package source-hash provenance closure evidence."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 282
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _count(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _status(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    status = value.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if status == "PASS" and not _text(value.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and value.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_v282(value: Any, label: str = "source_provenance_v282") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in (
        "build_label",
        "source_id",
        "provenance_id",
        "source_commit",
        "source_hash",
        "source_version",
        "package_version",
        "closure_id",
        "closure_digest",
    ):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("source_artifact_hash_count", "package_artifact_hash_count", "closure_entry_count"):
        if not _count(value.get(key)):
            errors.append(f"{label}.{key} must be a non-negative integer")

    binding_keys = (
        "source_id",
        "source_commit",
        "source_hash",
        "source_version",
        "package_version",
        "source_artifact_hash_count",
        "package_artifact_hash_count",
        "closure_id",
        "closure_digest",
        "closure_entry_count",
    )
    source = value.get("source")
    _status(source, f"{label}.source", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        for key in binding_keys:
            if source.get(key) != value.get(key):
                errors.append(f"{label}.source.{key} must match {key}")
        if source.get("identified") is not True:
            errors.append(f"{label}.source.identified must be true when status is PASS")

    provenance = value.get("provenance")
    _status(provenance, f"{label}.provenance", errors)
    if isinstance(provenance, dict) and provenance.get("status") == "PASS":
        for key in ("provenance_id",) + binding_keys:
            if provenance.get(key) != value.get(key):
                errors.append(f"{label}.provenance.{key} must match {key}")
        if provenance.get("proven") is not True:
            errors.append(f"{label}.provenance.proven must be true when status is PASS")

    closure = value.get("closure")
    _status(closure, f"{label}.closure", errors)
    if isinstance(closure, dict) and closure.get("status") == "PASS":
        for key in ("closure_id", "closure_digest", "closure_entry_count", "source_hash", "package_artifact_hash_count"):
            if closure.get(key) != value.get(key):
                errors.append(f"{label}.closure.{key} must match {key}")
        if closure.get("closed") is not True:
            errors.append(f"{label}.closure.closed must be true when status is PASS")

    for name in ("native_execution", "hardware_execution", "human_review"):
        gate = value.get(name)
        _status(gate, f"{label}.{name}", errors)
        if isinstance(gate, dict) and gate.get("status") == "NOT_RUN":
            for key in ("platform", "hardware", "reviewer", "evidence_path"):
                if gate.get(key) is not None:
                    errors.append(f"{label}.{name}.{key} must be null when status is NOT_RUN")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_v282(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_PROVENANCE_V282_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_PROVENANCE_V282_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
