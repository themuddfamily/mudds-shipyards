#!/usr/bin/env python3
"""Validate a source-to-native-package evidence handoff.

This is a record validator only.  It never builds, signs, installs, or runs an
artifact.  In particular, ``NOT_RUN`` is an intentional state for native
execution and must carry no execution evidence; a reason may document why the
gate was unavailable.
"""

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


def _status(record: Any, label: str, errors: list[str], *, reason: bool = False) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    state = record.get("status")
    if state not in STATUSES:
        errors.append(f"{label}.status is invalid")
        return
    evidence = record.get("evidence")
    if state == "PASS" and not _text(evidence):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and evidence is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")
    if reason and state == "NOT_RUN" and "reason" in record and not _text(record["reason"]):
        errors.append(f"{label}.reason must be non-empty when provided")


def validate_handoff(value: Any, label: str = "handoff") -> list[str]:
    """Return contract violations; an empty list means the record is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    artifact = value.get("artifact")
    _status(artifact, f"{label}.artifact", errors)
    if isinstance(artifact, dict) and artifact.get("status") == "PASS":
        for key in ("path", "sha256"):
            if not _text(artifact.get(key)):
                errors.append(f"{label}.artifact.{key} is required when status is PASS")
        if not _digest(artifact.get("sha256")):
            errors.append(f"{label}.artifact.sha256 must be a 64-character hex digest")

    embedded_pack = value.get("embedded_pack")
    _status(embedded_pack, f"{label}.embedded_pack", errors)
    if isinstance(embedded_pack, dict) and embedded_pack.get("status") == "PASS":
        if embedded_pack.get("embedded") is not True:
            errors.append(f"{label}.embedded_pack.embedded must be true when status is PASS")
        if not _text(embedded_pack.get("inventory")):
            errors.append(f"{label}.embedded_pack.inventory is required when status is PASS")

    signature = value.get("signature")
    _status(signature, f"{label}.signature", errors)
    if isinstance(signature, dict) and signature.get("status") == "PASS":
        if not _text(signature.get("method")):
            errors.append(f"{label}.signature.method is required when status is PASS")
        if not _text(signature.get("subject")):
            errors.append(f"{label}.signature.subject is required when status is PASS")

    runtime = value.get("runtime_smoke")
    _status(runtime, f"{label}.runtime_smoke", errors)
    native = value.get("native_execution")
    _status(native, f"{label}.native_execution", errors, reason=True)
    if isinstance(native, dict) and native.get("status") == "NOT_RUN":
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is NOT_RUN")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_handoff(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("NATIVE_ARTIFACT_HANDOFF_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("NATIVE_ARTIFACT_HANDOFF_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
