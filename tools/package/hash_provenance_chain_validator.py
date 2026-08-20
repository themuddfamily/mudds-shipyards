#!/usr/bin/env python3
"""Validate a recorded package hash/provenance chain without touching artifacts."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


def _status(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    state = record.get("status")
    if state not in STATUSES:
        errors.append(f"{label}.status is invalid")
        return
    if state == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_chain(value: Any, label: str = "chain") -> list[str]:
    """Return violations; an empty list means the recorded chain is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "source_manifest_sha256", "artifact_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key in ("source_manifest_sha256", "artifact_sha256"):
        if value.get(key) is not None and not _digest(value.get(key)):
            errors.append(f"{label}.{key} must be a 64-character hex digest")

    source = value.get("source")
    _status(source, f"{label}.source", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        if source.get("manifest_sha256") != value.get("source_manifest_sha256"):
            errors.append(f"{label}.source.manifest_sha256 must match chain.source_manifest_sha256")
        if source.get("commit") != value.get("source_commit"):
            errors.append(f"{label}.source.commit must match chain.source_commit")

    artifact = value.get("artifact")
    _status(artifact, f"{label}.artifact", errors)
    if isinstance(artifact, dict) and artifact.get("status") == "PASS":
        if artifact.get("sha256") != value.get("artifact_sha256"):
            errors.append(f"{label}.artifact.sha256 must match chain.artifact_sha256")
        if not _text(artifact.get("path")):
            errors.append(f"{label}.artifact.path is required when status is PASS")

    pck = value.get("pck")
    _status(pck, f"{label}.pck", errors)
    if isinstance(pck, dict) and pck.get("status") == "PASS":
        if not _digest(pck.get("sha256")):
            errors.append(f"{label}.pck.sha256 must be a 64-character hex digest")
        if not _text(pck.get("path")):
            errors.append(f"{label}.pck.path is required when status is PASS")
        if pck.get("embedded") is not True:
            errors.append(f"{label}.pck.embedded must be true when status is PASS")

    audit = value.get("audit")
    _status(audit, f"{label}.audit", errors)
    if isinstance(audit, dict) and audit.get("status") == "PASS":
        if audit.get("source_matches") is not True or audit.get("artifact_matches") is not True:
            errors.append(f"{label}.audit source_matches and artifact_matches must be true when status is PASS")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_chain(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("HASH_PROVENANCE_CHAIN_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("HASH_PROVENANCE_CHAIN_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
