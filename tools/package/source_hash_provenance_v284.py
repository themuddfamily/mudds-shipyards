#!/usr/bin/env python3
"""Validate version-284 package source-hash provenance review evidence."""
from __future__ import annotations
import argparse, json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 284
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(v: Any) -> bool:
    return isinstance(v, str) and bool(v.strip())


def _count(v: Any) -> bool:
    return isinstance(v, int) and not isinstance(v, bool) and v >= 0


def _status(v: Any, label: str, errors: list[str]) -> None:
    if not isinstance(v, dict):
        errors.append(f"{label} must be an object")
        return
    state = v.get("status")
    if state not in STATES:
        errors.append(f"{label}.status is invalid")
    elif state == "PASS" and not _text(v.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    elif state in {"NOT_RUN", "UNKNOWN"} and v.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_v284(value: Any, label: str = "source_provenance_v284") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_id", "source_commit", "source_hash", "package_version", "review_id", "review_timestamp"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("source_artifact_hash_count", "package_artifact_hash_count", "review_entry_count"):
        if not _count(value.get(key)):
            errors.append(f"{label}.{key} must be a non-negative integer")
    binding = ("source_id", "source_commit", "source_hash", "package_version", "source_artifact_hash_count", "package_artifact_hash_count", "review_id", "review_timestamp", "review_entry_count")
    source = value.get("source")
    _status(source, f"{label}.source", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        for key in binding:
            if source.get(key) != value.get(key):
                errors.append(f"{label}.source.{key} must match {key}")
        if source.get("identified") is not True:
            errors.append(f"{label}.source.identified must be true when status is PASS")
    review = value.get("review")
    _status(review, f"{label}.review", errors)
    if isinstance(review, dict) and review.get("status") == "PASS":
        for key in ("review_id", "review_timestamp", "source_hash", "package_artifact_hash_count", "review_entry_count"):
            if review.get(key) != value.get(key):
                errors.append(f"{label}.review.{key} must match {key}")
        if review.get("complete") is not True:
            errors.append(f"{label}.review.complete must be true when status is PASS")
    for name in ("native_execution", "hardware_execution", "human_review"):
        gate = value.get(name)
        _status(gate, f"{label}.{name}", errors)
        if isinstance(gate, dict) and gate.get("status") == "NOT_RUN":
            for key in ("platform", "hardware", "reviewer", "evidence_path"):
                if gate.get(key) is not None:
                    errors.append(f"{label}.{name}.{key} must be null when status is NOT_RUN")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("record", type=Path); args = parser.parse_args(argv)
    errors = validate_v284(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SOURCE_HASH_PROVENANCE_V284_INVALID"); print("\n".join(f"- {e}" for e in errors)); return 1
    print("SOURCE_HASH_PROVENANCE_V284_VALID"); return 0


if __name__ == "__main__":
    raise SystemExit(main())
