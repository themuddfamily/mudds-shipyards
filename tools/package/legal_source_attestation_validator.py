#!/usr/bin/env python3
"""Validate recorded legal/source provenance for a package, without publication."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


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


def validate_attestation(value: Any, label: str = "attestation") -> list[str]:
    """Return violations; an empty list means the source attestation is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_path"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("redistribution_authorized") is not False:
        errors.append(f"{label}.redistribution_authorized must be false")

    record = value.get("source_review")
    _status(record, f"{label}.source_review", errors)
    if isinstance(record, dict) and record.get("status") == "PASS":
        if not _text(record.get("reviewer")):
            errors.append(f"{label}.source_review.reviewer is required when status is PASS")
        if not _text(record.get("reviewed_at")):
            errors.append(f"{label}.source_review.reviewed_at is required when status is PASS")

    sources = value.get("sources")
    if not isinstance(sources, list) or not sources:
        errors.append(f"{label}.sources must be a non-empty list")
    else:
        identifiers: set[str] = set()
        for index, source in enumerate(sources):
            prefix = f"{label}.sources[{index}]"
            if not isinstance(source, dict):
                errors.append(f"{prefix} must be an object")
                continue
            identifier = source.get("identifier")
            if not _text(identifier):
                errors.append(f"{prefix}.identifier is required")
            elif identifier in identifiers:
                errors.append(f"{prefix}.identifier must be unique")
            else:
                identifiers.add(identifier)
            for key in ("kind", "license", "provenance", "evidence"):
                if not _text(source.get(key)):
                    errors.append(f"{prefix}.{key} is required")
            if source.get("redistributable") is not False:
                errors.append(f"{prefix}.redistributable must be false")

    completeness = value.get("completeness")
    _status(completeness, f"{label}.completeness", errors)
    if isinstance(completeness, dict) and completeness.get("status") == "PASS":
        if completeness.get("all_assets_accounted") is not True:
            errors.append(f"{label}.completeness.all_assets_accounted must be true when status is PASS")
        if completeness.get("unknown_assets") != 0:
            errors.append(f"{label}.completeness.unknown_assets must be 0 when status is PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_attestation(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("LEGAL_SOURCE_ATTESTATION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("LEGAL_SOURCE_ATTESTATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
