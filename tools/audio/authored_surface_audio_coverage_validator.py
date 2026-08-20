#!/usr/bin/env python3
"""Validate authored planetary surface-audio coverage evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "authored_surface_audio_coverage_v1"
REQUIRED_CONTEXTS = {"exterior", "interior", "landing_transition", "weather_response"}
STATUSES = {"CHECKED_IN", "CONTRACT_ONLY", "OUTSTANDING"}


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
    for key in ("revision", "world_id", "catalog_evidence"):
        if not _text(manifest.get(key)):
            errors.append(f"{key} is required")
    if manifest.get("audition_status") not in {"OPEN", "PASS", "FAILED"}:
        errors.append("audition_status is invalid")
    if manifest.get("audition_status") == "OPEN" and not _text(manifest.get("audition_boundary")):
        errors.append("audition_boundary is required while audition_status is OPEN")

    profiles = manifest.get("profiles")
    if not isinstance(profiles, list) or not profiles:
        errors.append("profiles must be a non-empty array")
        profiles = []
    contexts: set[str] = set()
    ids: set[str] = set()
    for index, profile in enumerate(profiles):
        prefix = f"profiles[{index}]"
        if not isinstance(profile, dict):
            errors.append(f"{prefix} must be an object")
            continue
        context = profile.get("context")
        if context not in REQUIRED_CONTEXTS:
            errors.append(f"{prefix}.context is invalid")
        else:
            contexts.add(context)
        profile_id = profile.get("profile_id")
        if not _text(profile_id):
            errors.append(f"{prefix}.profile_id is required")
        elif profile_id in ids:
            errors.append(f"{prefix}.profile_id is duplicated")
        else:
            ids.add(profile_id)
        for key in ("bus", "routing_evidence", "policy_evidence"):
            if not _text(profile.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if profile.get("bus") != "Ambience":
            errors.append(f"{prefix}.bus must be Ambience")
        status = profile.get("status")
        if status not in STATUSES:
            errors.append(f"{prefix}.status is invalid")
        if status == "CHECKED_IN" and not _paths(profile.get("asset_paths")):
            errors.append(f"{prefix}.asset_paths must be a non-empty unique list for CHECKED_IN")
        if status == "CONTRACT_ONLY" and profile.get("asset_paths") not in (None, []):
            errors.append(f"{prefix}.asset_paths must be empty for CONTRACT_ONLY")
        if status == "OUTSTANDING" and not _text(profile.get("notes")):
            errors.append(f"{prefix}.notes is required while status is OUTSTANDING")
    missing = REQUIRED_CONTEXTS - contexts
    if missing:
        errors.append(f"profiles must cover: {', '.join(sorted(missing))}")
    if manifest.get("claim") != "AUTOMATED_SURFACE_COVERAGE_ONLY":
        errors.append("claim must be AUTOMATED_SURFACE_COVERAGE_ONLY")
    if manifest.get("audition_status") == "PASS":
        errors.append("AUTOMATED_SURFACE_COVERAGE_ONLY cannot claim human audition PASS")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("AUTHORED_SURFACE_AUDIO_COVERAGE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUTHORED_SURFACE_AUDIO_COVERAGE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
