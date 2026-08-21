#!/usr/bin/env python3
"""Validate package source/hash provenance and authorization evidence for schema 329."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 329
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}

def _text(v: Any) -> bool:
    return isinstance(v, str) and bool(v.strip())

def _count(v: Any) -> bool:
    return isinstance(v, int) and not isinstance(v, bool) and v >= 0

def _status(v: Any, label: str, errors: list[str]) -> None:
    if not isinstance(v, dict):
        errors.append(f"{label} must be an object")
        return
    status = v.get("status")
    if status not in STATES:
        errors.append(f"{label}.status is invalid")
    elif status == "PASS" and not _text(v.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    elif status in {"NOT_RUN", "UNKNOWN"} and v.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")

def validate_v329(v: Any, label: str = "source_provenance_v329") -> list[str]:
    if not isinstance(v, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if v.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_id", "source_commit", "source_hash", "package_version",
                "authorization_attestation_id", "authorization_attestation_digest"):
        if not _text(v.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("source_artifact_hash_count", "package_artifact_hash_count", "authorization_attestation_entry_count"):
        if not _count(v.get(key)):
            errors.append(f"{label}.{key} must be a non-negative integer")
    source = v.get("source")
    _status(source, f"{label}.source", errors)
    source_keys = ("source_id", "source_commit", "source_hash", "package_version",
                   "source_artifact_hash_count", "package_artifact_hash_count",
                   "authorization_attestation_id", "authorization_attestation_digest",
                   "authorization_attestation_entry_count")
    if isinstance(source, dict) and source.get("status") == "PASS":
        for key in source_keys:
            if source.get(key) != v.get(key):
                errors.append(f"{label}.source.{key} must match {key}")
        if source.get("identified") is not True:
            errors.append(f"{label}.source.identified must be true when status is PASS")
    attestation = v.get("authorization_attestation")
    _status(attestation, f"{label}.authorization_attestation", errors)
    for key in ("authorization_attestation_id", "authorization_attestation_digest", "source_hash",
                "package_artifact_hash_count", "authorization_attestation_entry_count"):
        if isinstance(attestation, dict) and attestation.get("status") == "PASS" and attestation.get(key) != v.get(key):
            errors.append(f"{label}.authorization_attestation.{key} must match {key}")
    if isinstance(attestation, dict) and attestation.get("status") == "PASS" and attestation.get("authorized") is not True:
        errors.append(f"{label}.authorization_attestation.authorized must be true when status is PASS")
    for name in ("native_execution", "hardware_execution", "human_review"):
        gate = v.get(name)
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
    errors = validate_v329(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_PROVENANCE_V329_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_HASH_PROVENANCE_V329_VALID")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
