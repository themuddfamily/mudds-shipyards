#!/usr/bin/env python3
"""Validate credential-free Windows distribution readiness evidence.

This validator checks the operator-produced release record without signing,
installing, launching, or modifying a package.  Native and human gates are
deliberately required to remain NOT_RUN until their external evidence exists.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40,64}$")
ARTIFACT = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*-[0-9a-f]{7}\.exe$")
THUMBPRINT = re.compile(r"^[0-9a-fA-F]{40}$")
STATUSES = {"PASS", "FAIL", "NOT_RUN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _status(
    record: Any,
    label: str,
    errors: list[str],
    passing: set[str],
    allowed: set[str] | None = None,
) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    status = record.get("status")
    if status not in (allowed or STATUSES):
        errors.append(f"{label}.status is invalid")
        return
    evidence = record.get("evidence")
    if status in passing and not _text(evidence):
        errors.append(f"{label}.evidence is required when status is {status}")
    if status == "NOT_RUN" and evidence is not None:
        errors.append(f"{label}.evidence must be null when status is NOT_RUN")


def validate_readiness(value: Any, label: str = "readiness") -> list[str]:
    """Return contract violations; an empty list means the record is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")

    source_commit = value.get("source_commit")
    if not isinstance(source_commit, str) or not COMMIT.fullmatch(source_commit):
        errors.append(f"{label}.source_commit must be a 40-64 character hex commit")

    artifact = value.get("artifact")
    if not isinstance(artifact, dict):
        errors.append(f"{label}.artifact must be an object")
    else:
        name = artifact.get("name")
        if not isinstance(name, str) or not ARTIFACT.fullmatch(name):
            errors.append(f"{label}.artifact.name must be a revision-labelled .exe")
        digest = artifact.get("sha256")
        if not isinstance(digest, str) or not SHA256.fullmatch(digest):
            errors.append(f"{label}.artifact.sha256 must be a lowercase 64-character hex digest")
        size = artifact.get("size_bytes")
        if not isinstance(size, int) or isinstance(size, bool) or size <= 0:
            errors.append(f"{label}.artifact.size_bytes must be a positive integer")

    signing = value.get("signing")
    _status(
        signing,
        f"{label}.signing",
        errors,
        {"SIGNED"},
        {"SIGNED", "UNSIGNED", "FAIL", "NOT_RUN"},
    )
    if isinstance(signing, dict):
        status = signing.get("status")
        if status not in {"SIGNED", "UNSIGNED", "FAIL", "NOT_RUN"}:
            errors.append(f"{label}.signing.status is invalid")
        if status == "SIGNED":
            if not _text(signing.get("certificate_subject")):
                errors.append(f"{label}.signing.certificate_subject is required when signed")
            thumbprint = signing.get("certificate_thumbprint")
            if not isinstance(thumbprint, str) or not THUMBPRINT.fullmatch(thumbprint):
                errors.append(f"{label}.signing.certificate_thumbprint must be a 40-character hex thumbprint")
            if not _text(signing.get("timestamp_utc")):
                errors.append(f"{label}.signing.timestamp_utc is required when signed")
        elif any(signing.get(key) is not None for key in ("certificate_subject", "certificate_thumbprint", "timestamp_utc")):
            errors.append(f"{label}.signing certificate details must be null unless signed")

    _status(value.get("installer"), f"{label}.installer", errors, {"PASS"})
    _status(value.get("desktop_validation"), f"{label}.desktop_validation", errors, {"PASS"})

    for gate in ("native_execution", "human_playtest"):
        record = value.get(gate)
        _status(record, f"{label}.{gate}", errors, set())
        if isinstance(record, dict) and record.get("status") != "NOT_RUN":
            errors.append(f"{label}.{gate}.status must remain NOT_RUN")
    if value.get("distribution_allowed") is not False:
        errors.append(f"{label}.distribution_allowed must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.record.read_text(encoding="utf-8"))
        errors = validate_readiness(value)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        print(f"WINDOWS_DISTRIBUTION_READINESS_INVALID\n- {error}")
        return 1
    if errors:
        print("WINDOWS_DISTRIBUTION_READINESS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("WINDOWS_DISTRIBUTION_READINESS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
