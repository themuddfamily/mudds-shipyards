#!/usr/bin/env python3
"""Validate package signing and provenance evidence without cryptographic work.

This accepts operator-produced metadata only.  It does not sign, verify, or
publish an artifact; ``NOT_RUN`` means no signing/provenance check occurred and
therefore cannot carry a result or certificate claim.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


def _state(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    state = record.get("status")
    if state not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    evidence = record.get("evidence")
    if state == "PASS" and not _text(evidence):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and evidence is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_provenance(value: Any, label: str = "provenance") -> list[str]:
    """Return contract violations; an empty list means the record is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_path", "artifact_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("artifact_sha256") is not None and not _digest(value.get("artifact_sha256")):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest")

    signature = value.get("signature")
    _state(signature, f"{label}.signature", errors)
    if isinstance(signature, dict):
        status = signature.get("status")
        if status == "PASS":
            for key in ("algorithm", "certificate_subject", "certificate_digest"):
                if not _text(signature.get(key)):
                    errors.append(f"{label}.signature.{key} is required when status is PASS")
            if not _digest(signature.get("certificate_digest")):
                errors.append(f"{label}.signature.certificate_digest must be a 64-character hex digest")
        elif status in {"NOT_RUN", "UNKNOWN", "FAIL"}:
            for key in ("algorithm", "certificate_subject", "certificate_digest"):
                if signature.get(key) is not None:
                    errors.append(f"{label}.signature.{key} must be null when status is {status}")

    source = value.get("source_attestation")
    _state(source, f"{label}.source_attestation", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        if source.get("commit") != value.get("source_commit"):
            errors.append(f"{label}.source_attestation.commit must match source_commit")
        if not _text(source.get("manifest")):
            errors.append(f"{label}.source_attestation.manifest is required when status is PASS")

    if value.get("signature_grants_distribution_rights") is not False:
        errors.append(f"{label}.signature_grants_distribution_rights must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_provenance(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("SIGNING_PROVENANCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SIGNING_PROVENANCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
