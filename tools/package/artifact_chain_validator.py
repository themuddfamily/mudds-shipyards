#!/usr/bin/env python3
"""Fail-closed release artifact chain evidence validator.

The record joins build, embedded-PCK, source, signature, runtime, and update
evidence.  It records evidence only: it never exports, signs, installs, or
executes a package.  Native execution must therefore be stated explicitly.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
HEX64 = re.compile(r"^[0-9a-fA-F]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _hash(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


def _gate(record: Any, name: str, errors: list[str]) -> None:
    prefix = f"{name}"
    if not isinstance(record, dict):
        errors.append(f"{prefix} must be an object")
        return
    if record.get("status") not in STATUSES:
        errors.append(f"{prefix}.status is invalid")
    status = record.get("status")
    evidence = record.get("evidence")
    if status == "PASS" and not _text(evidence):
        errors.append(f"{prefix}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and evidence is not None:
        errors.append(f"{prefix}.evidence must be null when status is {status}")


def validate_chain(value: Any, label: str = "chain") -> list[str]:
    """Return violations; an empty list means the chain is structurally valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("release_version", "build_label", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    build = value.get("build")
    _gate(build, f"{label}.build", errors)
    if isinstance(build, dict) and build.get("status") == "PASS":
        for key in ("executable_path", "executable_sha256", "pck_path", "pck_sha256"):
            if not _text(build.get(key)):
                errors.append(f"{label}.build.{key} is required when build passes")
        for key in ("executable_sha256", "pck_sha256"):
            if build.get(key) is not None and not _hash(build[key]):
                errors.append(f"{label}.build.{key} must be a 64-character hex digest")

    pck = value.get("embedded_pck")
    _gate(pck, f"{label}.embedded_pck", errors)
    if isinstance(pck, dict) and pck.get("status") == "PASS":
        if pck.get("inventory_status") != "PASS":
            errors.append(f"{label}.embedded_pck.inventory_status must be PASS")
        if pck.get("embedded") is not True:
            errors.append(f"{label}.embedded_pck.embedded must be true")

    source = value.get("source_manifest")
    _gate(source, f"{label}.source_manifest", errors)
    if isinstance(source, dict) and source.get("status") == "PASS":
        if not _hash(source.get("manifest_sha256")):
            errors.append(f"{label}.source_manifest.manifest_sha256 must be a 64-character hex digest")

    for key in ("signature", "runtime_matrix", "update_compatibility"):
        _gate(value.get(key), f"{label}.{key}", errors)

    native = value.get("native_execution")
    _gate(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") == "NOT_RUN" and native.get("reason") is not None and not _text(native.get("reason")):
        errors.append(f"{label}.native_execution.reason must be non-empty when provided")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("chain", type=Path)
    args = parser.parse_args(argv)
    errors = validate_chain(json.loads(args.chain.read_text(encoding="utf-8")))
    if errors:
        print("PACKAGE_ARTIFACT_CHAIN_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGE_ARTIFACT_CHAIN_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
