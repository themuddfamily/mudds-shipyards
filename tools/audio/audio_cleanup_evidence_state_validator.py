#!/usr/bin/env python3
"""Validate equivalent v383–v1057 audio cleanup evidence/state summaries."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SUPPORTED_VERSIONS = range(383, 1058)
SCHEMAS = {f"audio_cleanup_evidence_state_v{version}": version for version in SUPPORTED_VERSIONS}
CLAIM = "AUTOMATED_EVIDENCE_STATE_ONLY"
NOT_RUN = "NOT_RUN"
BOUNDARY_FIELDS = ("detached_status", "native_status", "hardware_status", "human_review_status")
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _ids(value: Any) -> bool:
    return (isinstance(value, list) and bool(value) and all(_text(item) for item in value)
            and len(value) == len(set(value)) and value == sorted(value))


def validate_summary(summary: Any, *, schema_version: int | None = None) -> list[str]:
    """Validate a supported schema, optionally pinning the former versioned contract."""
    if schema_version is not None and schema_version not in SUPPORTED_VERSIONS:
        raise ValueError("schema_version must be between 383 and 1057")
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors = []
    schema = summary.get("schema")
    if schema_version is not None:
        expected = f"audio_cleanup_evidence_state_v{schema_version}"
        if schema != expected:
            errors.append(f"schema must be {expected}")
    elif not isinstance(schema, str) or schema not in SCHEMAS:
        errors.append("schema must be a supported audio_cleanup_evidence_state_v383–v1057 schema")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "evidence_id", "state_model"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != CLAIM:
        errors.append(f"claim must be {CLAIM}")
    for key in BOUNDARY_FIELDS:
        if summary.get(key) != NOT_RUN:
            errors.append(f"{key} must be NOT_RUN")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if summary.get("state") not in {"open", "ready", "closed"}:
        errors.append("state must be open, ready, or closed")
    ids = summary.get("record_ids")
    if not _ids(ids):
        errors.append("record_ids must be ordered, unique, and non-empty")
    for key in ("evidence_digest", "state_digest"):
        if not _digest(summary.get(key)):
            errors.append(f"{key} must be a lowercase 64-character digest")
    records = summary.get("records")
    if not isinstance(records, list) or not records:
        errors.append("records must be a non-empty array")
        records = []
    seen = set()
    for index, record in enumerate(records):
        prefix = f"records[{index}]"
        if not isinstance(record, dict):
            errors.append(f"{prefix} must be an object")
            continue
        record_id = record.get("record_id")
        if not _text(record_id):
            errors.append(f"{prefix}.record_id is required")
        elif record_id in seen:
            errors.append(f"{prefix}.record_id is duplicated")
        else:
            seen.add(record_id)
        if isinstance(ids, list) and record_id not in ids:
            errors.append(f"{prefix}.record_id must be in record_ids")
        for key in ("evidence_digest", "state_digest"):
            if not _digest(record.get(key)):
                errors.append(f"{prefix}.{key} must be a lowercase 64-character digest")
            elif record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        for key in ("evidence_id", "state_model", "state"):
            if record.get(key) != summary.get(key):
                errors.append(f"{prefix}.{key} must match summary")
        if not _text(record.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if record.get("state_pass") is not True:
            errors.append(f"{prefix}.state_pass must be true")
    if isinstance(ids, list) and seen != set(ids):
        errors.append("record_ids must exactly match records")
    if summary.get("evidence_state_pass") is not True:
        errors.append("evidence_state_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    parser.add_argument("--schema-version", type=int, help="Require an exact legacy schema version (383–1057).")
    args = parser.parse_args(argv)
    if args.schema_version is not None and args.schema_version not in SUPPORTED_VERSIONS:
        parser.error("--schema-version must be between 383 and 1057")
    summary = json.loads(args.summary.read_text(encoding="utf-8"))
    errors = validate_summary(summary, schema_version=args.schema_version)
    schema = summary.get("schema") if isinstance(summary, dict) else None
    version = args.schema_version
    if version is None and isinstance(schema, str):
        version = SCHEMAS.get(schema)
    banner = "AUDIO_CLEANUP_EVIDENCE_STATE" + (f"_V{version}" if version is not None else "")
    if errors:
        print(f"{banner}_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(f"{banner}_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
