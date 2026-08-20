#!/usr/bin/env python3
"""Validate the evidence record for a native-Windows package review.

This is deliberately an evidence gate: it does not pretend that a Linux
headless run is a Windows or controller-only run.  Each review dimension may
be ``NOT_RUN`` while work is in progress, but that state is explicit.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

SCHEMA = "native_windows_review_manifest_v1"
STATUSES = {"NOT_RUN", "IN_PROGRESS", "COMPLETE"}
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _review(errors: list[str], data: dict, key: str) -> None:
    value = data.get(key)
    label = key
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    status = value.get("status")
    if status not in STATUSES:
        errors.append(f"{label}.status must be NOT_RUN, IN_PROGRESS, or COMPLETE")
    evidence = value.get("evidence")
    if status == "NOT_RUN":
        if evidence is not None:
            errors.append(f"{label}.evidence must be null when status is NOT_RUN")
    elif not _text(evidence):
        errors.append(f"{label}.evidence is required when status is {status}")


def validate(manifest_path: Path) -> list[str]:
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    errors: list[str] = []
    required = ("schema", "target", "package", "controller_only_run", "visual_review", "performance_review")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")

    target = data["target"]
    if not isinstance(target, dict):
        errors.append("target must be an object")
    else:
        if target.get("os") != "Windows":
            errors.append("target.os must be Windows")
        if not _text(target.get("architecture")):
            errors.append("target.architecture is required")
        if not _text(target.get("build_identity")):
            errors.append("target.build_identity is required")

    package = data["package"]
    if not isinstance(package, dict):
        errors.append("package must be an object")
    else:
        if not _text(package.get("path")):
            errors.append("package.path is required")
        digest = package.get("sha256")
        if not isinstance(digest, str) or not SHA256.fullmatch(digest):
            errors.append("package.sha256 must be a 64-character hexadecimal digest")

    _review(errors, data, "controller_only_run")
    _review(errors, data, "visual_review")
    _review(errors, data, "performance_review")
    return errors


def package_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"NATIVE_WINDOWS_REVIEW_MANIFEST_FAILED: {error}")
        return 1
    print(f"NATIVE_WINDOWS_REVIEW_MANIFEST_VALID: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
