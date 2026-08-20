#!/usr/bin/env python3
"""Validate package/runtime evidence without running a package.

This is an evidence-shape and hash validator.  It deliberately does not infer
native execution, performance, or human-playtest completion from metadata.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN"}
CHECKPOINTS = ("cold_boot", "begin", "traverse", "launch", "land", "reenter")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _hash(value: Any) -> bool:
    return _text(value) and len(value) == 64 and all(c in "0123456789abcdefABCDEF" for c in value)


def _digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _record_errors(record: Any, index: int, base_dir: Path | None) -> list[str]:
    prefix = f"records[{index}]"
    errors: list[str] = []
    if not isinstance(record, dict):
        return [f"{prefix} must be an object"]
    for key in ("label", "source_commit", "artifact_path"):
        if not _text(record.get(key)):
            errors.append(f"{prefix}.{key} is required")
    if not _hash(record.get("artifact_sha256")):
        errors.append(f"{prefix}.artifact_sha256 must be a 64-character hex digest")
    if record.get("startup_status") not in STATUSES:
        errors.append(f"{prefix}.startup_status is invalid")
    checkpoints = record.get("loop_checkpoints")
    if not isinstance(checkpoints, dict):
        errors.append(f"{prefix}.loop_checkpoints must be an object")
    else:
        for checkpoint in CHECKPOINTS:
            if checkpoints.get(checkpoint) not in STATUSES:
                errors.append(f"{prefix}.loop_checkpoints.{checkpoint} is invalid or missing")
    source_hashes = record.get("source_hashes")
    if not isinstance(source_hashes, dict) or not source_hashes:
        errors.append(f"{prefix}.source_hashes must be a non-empty object")
    else:
        for path, digest in source_hashes.items():
            if not _text(path) or not _hash(digest):
                errors.append(f"{prefix}.source_hashes[{path!r}] must contain a 64-character hex digest")
    native = record.get("native_status")
    if native not in STATUSES:
        errors.append(f"{prefix}.native_status is invalid")
    if native == "NOT_RUN" and record.get("native_evidence") is not None:
        errors.append(f"{prefix}.native_evidence must be null when native_status is NOT_RUN")
    if native in {"PASS", "FAIL"} and not _text(record.get("native_evidence")):
        errors.append(f"{prefix}.native_evidence is required when native_status is {native}")
    claims = record.get("execution_claims", [])
    if claims not in (None, []):
        errors.append(f"{prefix}.execution_claims must be empty; this validator records evidence only")
    if base_dir is not None:
        artifact = base_dir / str(record.get("artifact_path", ""))
        if artifact.is_file() and _hash(record.get("artifact_sha256")) and _digest(artifact).lower() != record["artifact_sha256"].lower():
            errors.append(f"{prefix}.artifact_sha256 does not match artifact_path")
        for path, expected in (source_hashes.items() if isinstance(source_hashes, dict) else []):
            candidate = base_dir / path
            if candidate.is_file() and _hash(expected) and _digest(candidate).lower() != expected.lower():
                errors.append(f"{prefix}.source_hashes[{path!r}] does not match file")
    return errors


def validate_matrix(value: Any, base_dir: Path | None = None) -> list[str]:
    if not isinstance(value, dict):
        return ["matrix must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"matrix.schema_version must be {SCHEMA_VERSION}")
    records = value.get("records")
    if not isinstance(records, list) or not records:
        return errors + ["matrix.records must be a non-empty array"]
    labels: set[str] = set()
    for index, record in enumerate(records):
        if isinstance(record, dict) and record.get("label") in labels:
            errors.append(f"records[{index}].label must be unique")
        if isinstance(record, dict) and _text(record.get("label")):
            labels.add(record["label"])
        errors.extend(_record_errors(record, index, base_dir))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", type=Path)
    parser.add_argument("--base-dir", type=Path)
    args = parser.parse_args(argv)
    errors = validate_matrix(json.loads(args.matrix.read_text(encoding="utf-8")), args.base_dir)
    if errors:
        print("PACKAGE_RUNTIME_MATRIX_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGE_RUNTIME_MATRIX_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
