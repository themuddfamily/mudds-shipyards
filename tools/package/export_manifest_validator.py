#!/usr/bin/env python3
"""Validate evidence metadata for a packaged-build candidate.

This is a claim-safety gate: it validates the record, but never exports or
launches a package.  ``native_playtest_status`` must remain ``NOT_RUN`` until
an operator supplies native evidence; a manifest cannot turn metadata into a
playtest claim.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
NATIVE_STATUSES = {"NOT_RUN", "PASS", "FAIL"}
SIGNING_STATUSES = {"SIGNED", "UNSIGNED", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "godot_version", "artifact_path", "artifact_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    digest = value.get("artifact_sha256")
    if _text(digest) and (len(digest) != 64 or any(c not in "0123456789abcdefABCDEF" for c in digest)):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest")
    size = value.get("artifact_size_bytes")
    if not isinstance(size, int) or size <= 0:
        errors.append(f"{label}.artifact_size_bytes must be a positive integer")
    if value.get("signing_status") not in SIGNING_STATUSES:
        errors.append(f"{label}.signing_status is invalid")
    native = value.get("native_playtest_status")
    if native not in NATIVE_STATUSES:
        errors.append(f"{label}.native_playtest_status is invalid")
    if native == "NOT_RUN" and value.get("native_playtest_evidence") is not None:
        errors.append(f"{label}.native_playtest_evidence must be null when status is NOT_RUN")
    if native in {"PASS", "FAIL"} and not _text(value.get("native_playtest_evidence")):
        errors.append(f"{label}.native_playtest_evidence is required when native playtest ran")
    pck = value.get("embedded_pck_inventory")
    if not isinstance(pck, list) or not pck or not all(_text(item) for item in pck):
        errors.append(f"{label}.embedded_pck_inventory must be a non-empty array of paths")
    if value.get("smoke_status") not in {"PASS", "FAIL", "NOT_RUN"}:
        errors.append(f"{label}.smoke_status is invalid")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PACKAGE_EXPORT_MANIFEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGE_EXPORT_MANIFEST_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
