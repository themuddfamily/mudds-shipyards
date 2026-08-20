#!/usr/bin/env python3
"""Validate source-current five-berth capture rerun provenance.

This gate checks bytes, source-ledger references, and revision identity.  It
does not render frames, authenticate the source material, or make an art
quality/sign-off decision.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any

SCHEMA = "station_capture_currentness_v1"
BERTHS = ("central", "aft", "habitat", "freight", "fleet_dock")
REVISION_RE = re.compile(r"^[0-9a-f]{7,64}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _revision(value: Any) -> bool:
    return isinstance(value, str) and bool(REVISION_RE.fullmatch(value))


def _load(path: Path) -> tuple[Any | None, list[str]]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), []
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        return None, [f"{path.name} unreadable: {exc}"]


def _git_revision(repository: Path) -> tuple[str | None, list[str]]:
    try:
        result = subprocess.run(
            ["git", "-C", str(repository), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        return None, [f"cannot determine current source revision: {exc}"]
    revision = result.stdout.strip()
    if not _revision(revision):
        return None, ["current source revision is not a hexadecimal git revision"]
    return revision, []


def validate(manifest_path: Path, current_revision: str | None = None) -> list[str]:
    """Return blocking errors for a rerun manifest.

    ``current_revision`` is injectable for deterministic callers; the CLI
    obtains it from the requested repository.  The manifest may use a short
    revision, but it must match the supplied current revision exactly.
    """
    data, errors = _load(manifest_path)
    if not isinstance(data, dict):
        return errors or ["manifest root must be an object"]
    if data.get("schema") != SCHEMA:
        errors.append(f"unsupported schema: {data.get('schema')!r}")
    source_revision = data.get("source_revision")
    if not _revision(source_revision):
        errors.append("source_revision must be a hexadecimal source revision")
    if current_revision is not None:
        if not _revision(current_revision):
            errors.append("current_revision must be a hexadecimal source revision")
        elif source_revision != current_revision:
            errors.append("source_revision does not match current source revision")
    if data.get("human_review_status") not in {"pending", "not_performed"}:
        errors.append("human_review_status must remain pending or not_performed")
    if not _text(data.get("reviewer_required")):
        errors.append("reviewer_required must identify the manual reviewer role")

    ledger_info = data.get("source_ledger")
    if not isinstance(ledger_info, dict):
        errors.append("source_ledger must be an object")
        ledger_info = {}
    ledger_name = ledger_info.get("path")
    ledger_path = manifest_path.parent / ledger_name if _text(ledger_name) else None
    ledger: Any = None
    if ledger_path is None:
        errors.append("source_ledger.path is required")
    elif not ledger_path.is_file():
        errors.append(f"source ledger not found: {ledger_path}")
    else:
        recorded_ledger_hash = ledger_info.get("sha256")
        if not isinstance(recorded_ledger_hash, str) or not SHA256_RE.fullmatch(recorded_ledger_hash):
            errors.append("source_ledger.sha256 must be a 64-character digest")
        elif sha256(ledger_path) != recorded_ledger_hash:
            errors.append("source ledger SHA-256 does not match manifest")
        ledger, load_errors = _load(ledger_path)
        errors.extend(load_errors)
    source_ids: set[str] = set()
    if isinstance(ledger, dict) and isinstance(ledger.get("sources"), list):
        source_ids = {item.get("id") for item in ledger["sources"] if isinstance(item, dict)}
    elif ledger is not None:
        errors.append("source ledger must contain a sources list")

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
        path = manifest_path.parent / path_name if _text(path_name) else None
        if path is None:
            errors.append(f"{berth!r}: capture path is required")
        elif not path.is_file():
            errors.append(f"{berth!r}: capture not found: {path}")
        else:
            recorded = capture.get("sha256")
            if not isinstance(recorded, str) or not SHA256_RE.fullmatch(recorded):
                errors.append(f"{berth!r}: sha256 must be a 64-character digest")
            elif sha256(path) != recorded:
                errors.append(f"{berth!r}: SHA-256 does not match manifest")
        if not _text(capture.get("viewpoint")):
            errors.append(f"{berth!r}: viewpoint is required")
        if capture.get("source_current") is not True:
            errors.append(f"{berth!r}: source_current must be true")
        if capture.get("source_revision") != source_revision:
            errors.append(f"{berth!r}: source_revision does not match manifest")
        refs = capture.get("source_refs")
        if not isinstance(refs, list) or not refs or any(not isinstance(ref, str) or not ref for ref in refs):
            errors.append(f"{berth!r}: source_refs must contain at least one source ID")
        else:
            for ref in refs:
                if ref not in source_ids:
                    errors.append(f"{berth!r}: unregistered source reference: {ref}")
    missing = set(BERTHS) - seen
    if missing:
        errors.append("missing berth captures: " + ", ".join(sorted(missing)))
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--repository", type=Path, required=True)
    args = parser.parse_args(argv)
    current, errors = _git_revision(args.repository.resolve())
    if not errors and current is not None:
        errors.extend(validate(args.manifest.resolve(), current))
    for error in errors:
        print(f"STATION_CAPTURE_CURRENTNESS_FAILED: {error}")
    if not errors:
        print("STATION_CAPTURE_CURRENTNESS_READY: human review still required")
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
