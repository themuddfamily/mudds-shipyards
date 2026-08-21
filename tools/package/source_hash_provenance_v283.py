#!/usr/bin/env python3
"""Validate version-283 package source-hash provenance attestation evidence."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 283
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _nonnegative(value: Any) -> bool:
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


def validate_v283(value: Any, label: str = "source_provenance_v283") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_id", "provenance_id", "source_commit", "source_hash", "package_version", "attestation_id", "attestation_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("source_artifact_hash_count", "package_artifact_hash_count", "attestation_entry_count"):
        if not _nonnegative(value.get(key)):
            errors.append(f"{label}.{key} must be a non-negative integer")

    binding = ("source_id", "source_commit", "source_hash", "package_version", "source_artifact_hash_count", "package_artifact_hash_count", "attestation_id", "attestation_digest", "attestation_entry_count")
    source = value.get("source")
    _status(source, f"{label}.source", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        for key in binding:
            if source.get(key) != value.get(key):
                errors.append(f"{label}.source.{key} must match {key}")
        if source.get("identified") is not True:
            errors.append(f"{label}.source.identified must be true when status is PASS")

    attestation = value.get("attestation")
    _status(attestation, f"{label}.attestation", errors)
    if isinstance(attestation, dict) and attestation.get("status") == "PASS":
        for key in ("provenance_id", "attestation_id", "attestation_digest", "source_hash", "package_artifact_hash_count", "attestation_entry_count"):
            if attestation.get(key) != value.get(key):
                errors.append(f"{label}.attestation.{key} must match {key}")
        if attestation.get("attested") is not True:
            errors.append(f"{label}.attestation.attested must be true when status is PASS")

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
    errors = validate_v283(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_PROVENANCE_V283_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_PROVENANCE_V283_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
