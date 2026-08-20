#!/usr/bin/env python3
"""Validate broad authored-audio asset coverage and its human-review boundary."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "authored_audio_coverage_v1"
CATEGORIES = {"music", "machinery", "combat", "planetary_surface", "ui"}
STATUSES = {"CHECKED_IN", "MISSING", "OUTSTANDING"}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _paths(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_manifest(manifest: Any) -> list[str]:
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    source = manifest.get("source")
    if not isinstance(source, dict):
        errors.append("source must be an object")
        source = {}
    for key in ("revision", "provenance_owner"):
        if not _text(source.get(key)):
            errors.append(f"source.{key} is required")

    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        errors.append("assets must be a non-empty array")
        assets = []
    ids: set[str] = set()
    categories: set[str] = set()
    for index, asset in enumerate(assets):
        prefix = f"assets[{index}]"
        if not isinstance(asset, dict):
            errors.append(f"{prefix} must be an object")
            continue
        asset_id = asset.get("asset_id")
        if not _text(asset_id):
            errors.append(f"{prefix}.asset_id is required")
        elif asset_id in ids:
            errors.append(f"{prefix}.asset_id is duplicated")
        else:
            ids.add(asset_id)
        category = asset.get("category")
        if category not in CATEGORIES:
            errors.append(f"{prefix}.category is invalid")
        else:
            categories.add(category)
        if not _paths(asset.get("paths")):
            errors.append(f"{prefix}.paths must be a non-empty unique array")
        digest = asset.get("sha256")
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")
        for key in ("generator_or_source", "bus", "runtime_evidence"):
            if not _text(asset.get(key)):
                errors.append(f"{prefix}.{key} is required")
        status = asset.get("status")
        if status not in STATUSES:
            errors.append(f"{prefix}.status is invalid")
        if status == "MISSING":
            errors.append(f"{prefix}.status MISSING blocks authored coverage")
        if status == "OUTSTANDING" and not _text(asset.get("notes")):
            errors.append(f"{prefix}.notes is required while status is OUTSTANDING")
    missing = CATEGORIES - categories
    if missing:
        errors.append(f"assets must cover categories: {', '.join(sorted(missing))}")

    review = manifest.get("human_audition")
    if not isinstance(review, dict):
        errors.append("human_audition must be an object")
        review = {}
    if review.get("status") not in {"OPEN", "PASS", "FAILED"}:
        errors.append("human_audition.status is invalid")
    if review.get("status") == "PASS":
        for key in ("reviewer", "device", "evidence", "notes"):
            if not _text(review.get(key)):
                errors.append(f"human_audition.{key} is required for PASS")
    elif review.get("status") == "OPEN" and not _text(review.get("boundary_note")):
        errors.append("human_audition.boundary_note is required while audition is OPEN")
    if manifest.get("claim") == "AUTOMATED_COVERAGE_ONLY":
        if review.get("status") == "PASS":
            errors.append("AUTOMATED_COVERAGE_ONLY cannot contain a human_audition PASS")
    elif manifest.get("claim") == "HUMAN_AUDITION_PASS":
        if review.get("status") != "PASS":
            errors.append("HUMAN_AUDITION_PASS requires human_audition PASS")
    else:
        errors.append("claim must be AUTOMATED_COVERAGE_ONLY or HUMAN_AUDITION_PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("AUTHORED_AUDIO_COVERAGE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUTHORED_AUDIO_COVERAGE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
