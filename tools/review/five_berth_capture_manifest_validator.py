#!/usr/bin/env python3
"""Validate the rendered five-berth evidence handoff (ROADMAP 625).

This is a provenance gate, not an art-quality verdict: it checks that exactly
one current-source frame exists for each berth, that the declared viewpoint and
digest are reproducible, and that a human review is still explicitly pending.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

SCHEMA = "five_berth_capture_manifest_v1"
BERTHS = {"central", "aft", "habitat", "freight", "fleet_dock"}
PENDING = {"pending", "not_performed"}


def _digest(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(manifest_path: Path) -> list[str]:
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    errors: list[str] = []
    if data.get("schema") != SCHEMA:
        errors.append(f"unsupported schema: {data.get('schema')!r}")
    if not _text(data.get("source_revision")):
        errors.append("source_revision must identify the rendered source revision")
    status = data.get("human_review_status")
    if status not in PENDING:
        errors.append("human_review_status must remain pending or not_performed")
    if not _text(data.get("reviewer_required")):
        errors.append("reviewer_required must identify the manual reviewer role")
    captures = data.get("captures")
    if not isinstance(captures, list) or len(captures) != len(BERTHS):
        errors.append("captures must contain exactly five berth frames")
        captures = captures if isinstance(captures, list) else []
    seen: set[str] = set()
    for capture in captures:
        if not isinstance(capture, dict):
            errors.append("each capture must be an object")
            continue
        berth = capture.get("berth")
        if berth not in BERTHS:
            errors.append(f"unknown or missing berth: {berth!r}")
        elif berth in seen:
            errors.append(f"duplicate berth capture: {berth}")
        else:
            seen.add(berth)
        path_name = capture.get("path")
        if not _text(path_name):
            errors.append(f"{berth!r}: capture path is required")
            continue
        path = manifest_path.parent / path_name
        if not path.is_file():
            errors.append(f"{berth!r}: capture not found: {path}")
            continue
        recorded = capture.get("sha256")
        if not isinstance(recorded, str) or len(recorded) != 64:
            errors.append(f"{berth!r}: sha256 must be a 64-character digest")
        elif _digest(path) != recorded:
            errors.append(f"{berth!r}: SHA-256 does not match manifest")
        if not _text(capture.get("viewpoint")):
            errors.append(f"{berth!r}: viewpoint is required")
        if capture.get("source_current") is not True:
            errors.append(f"{berth!r}: source_current must be true")
        if capture.get("source_revision") != data.get("source_revision"):
            errors.append(f"{berth!r}: source_revision does not match manifest")
    missing = BERTHS - seen
    if missing:
        errors.append("missing berth captures: " + ", ".join(sorted(missing)))
    return errors


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    failures = validate(args.manifest.resolve())
    for failure in failures:
        print(f"FIVE_BERTH_CAPTURE_FAILED: {failure}")
    if not failures:
        print("FIVE_BERTH_CAPTURE_READY: human review still required")
    raise SystemExit(bool(failures))
