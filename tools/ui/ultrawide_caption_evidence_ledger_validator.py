#!/usr/bin/env python3
"""Validate ultrawide/caption presentation evidence without claiming hardware review."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "ultrawide_caption_evidence_v1"
REQUIRED_ASPECTS = {"16:9", "16:10", "21:9", "32:9"}
EVIDENCE_STATUSES = {"AUTOMATED_PASS", "HUMAN_REVIEW_OPEN", "HUMAN_PASS", "FAILED"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _paths(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_ledger(ledger: Any) -> list[str]:
    if not isinstance(ledger, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if ledger.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    source = ledger.get("source")
    if not isinstance(source, dict):
        errors.append("source must be an object")
        source = {}
    for key in ("revision", "layout_owner"):
        if not _text(source.get(key)):
            errors.append(f"source.{key} is required")
    if ledger.get("hardware_review") != "OPEN":
        errors.append("hardware_review must be OPEN until a human device review is recorded")

    ultrawide = ledger.get("ultrawide")
    if not isinstance(ultrawide, dict):
        errors.append("ultrawide must be an object")
        ultrawide = {}
    aspects = ultrawide.get("aspect_ratios")
    if not isinstance(aspects, list) or any(not _text(item) for item in aspects) or len(set(aspects)) != len(aspects):
        errors.append("ultrawide.aspect_ratios must be a unique list of strings")
    elif not REQUIRED_ASPECTS.issubset(aspects):
        errors.append("ultrawide.aspect_ratios must cover 16:9, 16:10, 21:9, and 32:9")
    for key in ("safe_area_evidence", "focus_evidence"):
        if not _paths(ultrawide.get(key)):
            errors.append(f"ultrawide.{key} must be a non-empty unique list of paths")
    if ultrawide.get("status") not in EVIDENCE_STATUSES:
        errors.append("ultrawide.status is invalid")
    if ultrawide.get("status") == "HUMAN_PASS":
        errors.append("ultrawide.status HUMAN_PASS is not allowed while hardware_review is OPEN")

    captions = ledger.get("captions")
    if not isinstance(captions, dict):
        errors.append("captions must be an object")
        captions = {}
    for key in ("scenarios", "viewport_evidence", "contrast_evidence"):
        if not _paths(captions.get(key)):
            errors.append(f"captions.{key} must be a non-empty unique list of paths")
    if captions.get("status") not in EVIDENCE_STATUSES:
        errors.append("captions.status is invalid")
    contract = captions.get("contract")
    if not isinstance(contract, dict):
        errors.append("captions.contract must be an object")
        contract = {}
    for key in ("minimum_scale", "maximum_scale", "minimum_contrast_ratio", "maximum_text_characters"):
        value = contract.get(key)
        if not isinstance(value, (int, float)) or isinstance(value, bool) or value <= 0:
            errors.append(f"captions.contract.{key} must be positive")
    if isinstance(contract.get("minimum_scale"), (int, float)) and isinstance(contract.get("maximum_scale"), (int, float)) and contract["minimum_scale"] >= contract["maximum_scale"]:
        errors.append("captions.contract.minimum_scale must be less than maximum_scale")
    if captions.get("status") == "HUMAN_PASS":
        errors.append("captions.status HUMAN_PASS is not allowed while hardware_review is OPEN")

    claim = ledger.get("claim")
    if claim == "AUTOMATED_LAYOUT_ONLY":
        if not _text(ledger.get("boundary_note")):
            errors.append("boundary_note is required for AUTOMATED_LAYOUT_ONLY")
    elif claim == "HUMAN_PRESENTATION_PASS":
        errors.append("claim HUMAN_PRESENTATION_PASS is blocked while hardware_review is OPEN")
    else:
        errors.append("claim must be AUTOMATED_LAYOUT_ONLY or HUMAN_PRESENTATION_PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("ULTRAWIDE_CAPTION_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ULTRAWIDE_CAPTION_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
