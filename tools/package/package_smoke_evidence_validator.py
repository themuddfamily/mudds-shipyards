#!/usr/bin/env python3
"""Validate machine-readable evidence from a packaged-build smoke pass.

The validator records evidence supplied by an operator; it never exports or
launches a package.  Native execution remains an explicit boundary and cannot
be inferred from a source-tree or metadata-only pass.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
NATIVE_STATUSES = {"NOT_RUN", "PASS", "FAIL"}
STARTUP_STATUSES = {"PASS", "FAIL", "NOT_RUN"}
REQUIRED_CHECKPOINTS = ("cold_boot", "begin", "traverse", "launch", "land", "reenter")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(path: Path) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def _valid_hash(value: Any) -> bool:
    return _text(value) and len(value) == 64 and all(c in "0123456789abcdefABCDEF" for c in value)


def validate_evidence(value: Any, base_dir: Path | None = None) -> list[str]:
    """Return all contract violations, including mismatched available files."""
    errors: list[str] = []
    if not isinstance(value, dict):
        return ["evidence must be an object"]
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"evidence.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "godot_version", "artifact_path"):
        if not _text(value.get(key)):
            errors.append(f"evidence.{key} is required")
    if not _valid_hash(value.get("artifact_sha256")):
        errors.append("evidence.artifact_sha256 must be a 64-character hex digest")
    startup = value.get("startup_status")
    if startup not in STARTUP_STATUSES:
        errors.append("evidence.startup_status is invalid")
    checkpoints = value.get("loop_checkpoints")
    if not isinstance(checkpoints, dict):
        errors.append("evidence.loop_checkpoints must be an object")
    else:
        for key in REQUIRED_CHECKPOINTS:
            if checkpoints.get(key) != "PASS":
                errors.append(f"evidence.loop_checkpoints.{key} must be PASS")
    sources = value.get("source_hashes")
    if not isinstance(sources, dict) or not sources:
        errors.append("evidence.source_hashes must be a non-empty object")
    else:
        for path, digest in sources.items():
            if not _text(path) or not _valid_hash(digest):
                errors.append(f"evidence.source_hashes[{path!r}] must contain a 64-character hex digest")
    native = value.get("native_status")
    if native not in NATIVE_STATUSES:
        errors.append("evidence.native_status is invalid")
    if native == "NOT_RUN" and value.get("native_evidence") is not None:
        errors.append("evidence.native_evidence must be null when native_status is NOT_RUN")
    if native in {"PASS", "FAIL"} and not _text(value.get("native_evidence")):
        errors.append("evidence.native_evidence is required when native_status is PASS or FAIL")

    if base_dir is not None:
        artifact = base_dir / str(value.get("artifact_path", ""))
        if artifact.is_file() and _valid_hash(value.get("artifact_sha256")):
            if _digest(artifact).lower() != str(value["artifact_sha256"]).lower():
                errors.append("evidence.artifact_sha256 does not match artifact_path")
        for path, expected in (sources.items() if isinstance(sources, dict) else []):
            candidate = base_dir / path
            if candidate.is_file() and _valid_hash(expected) and _digest(candidate).lower() != str(expected).lower():
                errors.append(f"evidence.source_hashes[{path!r}] does not match file")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    parser.add_argument("--base-dir", type=Path, default=None)
    args = parser.parse_args(argv)
    errors = validate_evidence(json.loads(args.evidence.read_text(encoding="utf-8")), args.base_dir)
    if errors:
        print("PACKAGE_SMOKE_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGE_SMOKE_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
