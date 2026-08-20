#!/usr/bin/env python3
"""Validate v8 cleanup-digest rejection decision/evidence linkages."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_digest_rejection_evidence_linkage_summary_v8"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_REJECTION_LINKAGE_ONLY":
        errors.append("claim must be AUTOMATED_REJECTION_LINKAGE_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if not _digest(summary.get("accepted_digest")):
        errors.append("accepted_digest must be a lowercase 64-character digest")

    evidence = summary.get("evidence_records")
    evidence_ids: set[str] = set()
    if not isinstance(evidence, list) or not evidence:
        errors.append("evidence_records must be a non-empty array")
        evidence = []
    for index, row in enumerate(evidence):
        prefix = f"evidence_records[{index}]"
        if not isinstance(row, dict):
            errors.append(f"{prefix} must be an object")
            continue
        evidence_id = row.get("evidence_id")
        if not _text(evidence_id):
            errors.append(f"{prefix}.evidence_id is required")
        elif evidence_id in evidence_ids:
            errors.append(f"{prefix}.evidence_id is duplicated")
        else:
            evidence_ids.add(evidence_id)
        if not _text(row.get("path")):
            errors.append(f"{prefix}.path is required")
        if not _text(row.get("sha256")):
            errors.append(f"{prefix}.sha256 is required")
        elif not _digest(row["sha256"]):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")

    decisions = summary.get("decisions")
    decision_ids: set[str] = set()
    if not isinstance(decisions, list) or not decisions:
        errors.append("decisions must be a non-empty array")
        decisions = []
    for index, decision in enumerate(decisions):
        prefix = f"decisions[{index}]"
        if not isinstance(decision, dict):
            errors.append(f"{prefix} must be an object")
            continue
        decision_id = decision.get("decision_id")
        if not _text(decision_id):
            errors.append(f"{prefix}.decision_id is required")
        elif decision_id in decision_ids:
            errors.append(f"{prefix}.decision_id is duplicated")
        else:
            decision_ids.add(decision_id)
        if decision.get("result") not in {"ACCEPTED", "REJECTED"}:
            errors.append(f"{prefix}.result is invalid")
        digest = decision.get("digest")
        if not _digest(digest):
            errors.append(f"{prefix}.digest must be a lowercase 64-character digest")
        if decision.get("result") == "ACCEPTED" and digest != summary.get("accepted_digest"):
            errors.append(f"{prefix}.digest must match accepted_digest")
        evidence_id = decision.get("evidence_id")
        if evidence_id not in evidence_ids:
            errors.append(f"{prefix}.evidence_id must reference evidence_records")
        if not _text(decision.get("reason")):
            errors.append(f"{prefix}.reason is required")
    if summary.get("linkage_pass") is not True:
        errors.append("linkage_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_REJECTION_LINKAGE_V8_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_REJECTION_LINKAGE_V8_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
