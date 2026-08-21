#!/usr/bin/env python3
"""Validate version-326 package authorization attestation/source binding evidence."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 326
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
    elif status == "PASS" and not _text(value.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    elif status in {"NOT_RUN", "UNKNOWN"} and value.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_v326(value: Any, label: str = "source_provenance_v326") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    required = (
        "build_label", "source_id", "source_commit", "source_hash", "package_version",
        "authorization_attestation_id", "authorization_attestation_digest",
    )
    for key in required:
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("source_artifact_hash_count", "package_artifact_hash_count", "authorization_attestation_entry_count"):
        if not _count(value.get(key)):
            errors.append(f"{label}.{key} must be a non-negative integer")

    source = value.get("source")
    _status(source, f"{label}.source", errors)
    source_keys = (
        "source_id", "source_commit", "source_hash", "package_version",
        "source_artifact_hash_count", "package_artifact_hash_count",
        "authorization_attestation_id", "authorization_attestation_digest",
        "authorization_attestation_entry_count",
    )
    if isinstance(source, dict) and source.get("status") == "PASS":
        for key in source_keys:
            if source.get(key) != value.get(key):
                errors.append(f"{label}.source.{key} must match {key}")
        if source.get("identified") is not True:
            errors.append(f"{label}.source.identified must be true when status is PASS")

    attestation = value.get("authorization_attestation")
    _status(attestation, f"{label}.authorization_attestation", errors)
    attestation_keys = (
        "authorization_attestation_id", "authorization_attestation_digest", "source_hash",
        "package_artifact_hash_count", "authorization_attestation_entry_count",
    )
    if isinstance(attestation, dict) and attestation.get("status") == "PASS":
        for key in attestation_keys:
            if attestation.get(key) != value.get(key):
                errors.append(f"{label}.authorization_attestation.{key} must match {key}")
        if attestation.get("authorized") is not True:
            errors.append(f"{label}.authorization_attestation.authorized must be true when status is PASS")

    for gate_name in ("native_execution", "hardware_execution", "human_review"):
        gate = value.get(gate_name)
        _status(gate, f"{label}.{gate_name}", errors)
        if isinstance(gate, dict) and gate.get("status") == "NOT_RUN":
            for key in ("platform", "hardware", "reviewer", "evidence_path"):
                if gate.get(key) is not None:
                    errors.append(f"{label}.{gate_name}.{key} must be null when status is NOT_RUN")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_v326(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_PROVENANCE_V326_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_PROVENANCE_V326_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
