#!/usr/bin/env python3
"""Validate landing/cabin ambience cleanup endpoint evidence without audition."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_landing_cabin_cleanup_endpoint_v1"
REQUIRED_ENDPOINTS = {"landing_abort", "landing_complete", "cabin_exit", "detach"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_ledger(ledger: Any) -> list[str]:
    if not isinstance(ledger, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if ledger.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "evidence_bundle"):
        if not _text(ledger.get(key)):
            errors.append(f"{key} is required")
    if ledger.get("native_audition") != "OPEN":
        errors.append("native_audition must be OPEN")
    if ledger.get("claim") != "AUTOMATED_CLEANUP_ONLY":
        errors.append("claim must be AUTOMATED_CLEANUP_ONLY")
    if not _text(ledger.get("boundary_note")):
        errors.append("boundary_note is required")

    endpoints = ledger.get("endpoints")
    if not isinstance(endpoints, list) or not endpoints:
        errors.append("endpoints must be a non-empty array")
        endpoints = []
    seen: set[str] = set()
    for index, endpoint in enumerate(endpoints):
        prefix = f"endpoints[{index}]"
        if not isinstance(endpoint, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = endpoint.get("name")
        if name not in REQUIRED_ENDPOINTS:
            errors.append(f"{prefix}.name is invalid")
        elif name in seen:
            errors.append(f"{prefix}.name is duplicated")
        else:
            seen.add(name)
        for key in ("cleanup_evidence", "generation_evidence", "reason"):
            if not _text(endpoint.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if not _positive_int(endpoint.get("old_generation")) or not _positive_int(endpoint.get("new_generation")):
            errors.append(f"{prefix}.old_generation and new_generation must be positive integers")
        elif endpoint["new_generation"] <= endpoint["old_generation"]:
            errors.append(f"{prefix}.new_generation must be newer than old_generation")
        for key in ("voices_zero", "binding_cleared", "stale_callback_rejected", "presentation_only"):
            if endpoint.get(key) is not True:
                errors.append(f"{prefix}.{key} must be true")
    missing = REQUIRED_ENDPOINTS - seen
    if missing:
        errors.append(f"endpoints must cover: {', '.join(sorted(missing))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_LANDING_CABIN_CLEANUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_LANDING_CABIN_CLEANUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
