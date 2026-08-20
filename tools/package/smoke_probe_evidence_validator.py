#!/usr/bin/env python3
"""Validate packaged smoke and external-probe evidence records only."""

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


def _digest(value: Any) -> bool:
    return _text(value) and bool(HEX64.fullmatch(value.strip()))


def _check(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    status = record.get("status")
    if status not in STATUSES:
        errors.append(f"{label}.status is invalid")
        return
    evidence = record.get("evidence")
    if status == "PASS" and not _text(evidence):
        errors.append(f"{label}.evidence is required when status is PASS")
    if status in {"NOT_RUN", "UNKNOWN"} and evidence is not None:
        errors.append(f"{label}.evidence must be null when status is {status}")


def validate_smoke(value: Any, label: str = "smoke") -> list[str]:
    """Return violations; an empty list means the smoke record is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_path", "artifact_sha256"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    if value.get("artifact_sha256") is not None and not _digest(value.get("artifact_sha256")):
        errors.append(f"{label}.artifact_sha256 must be a 64-character hex digest")

    packaged = value.get("packaged_startup")
    _check(packaged, f"{label}.packaged_startup", errors)
    if isinstance(packaged, dict) and packaged.get("status") == "PASS":
        for key in ("exit_code", "frame_count"):
            if not isinstance(packaged.get(key), int) or packaged[key] < 0:
                errors.append(f"{label}.packaged_startup.{key} must be a non-negative integer when status is PASS")
        if packaged.get("exit_code") != 0:
            errors.append(f"{label}.packaged_startup.exit_code must be 0 when status is PASS")

    probes = value.get("probes")
    if not isinstance(probes, list) or not probes:
        errors.append(f"{label}.probes must be a non-empty list")
    else:
        names: set[str] = set()
        for index, probe in enumerate(probes):
            prefix = f"{label}.probes[{index}]"
            _check(probe, prefix, errors)
            if not isinstance(probe, dict):
                continue
            name = probe.get("name")
            if not _text(name):
                errors.append(f"{prefix}.name is required")
            elif name in names:
                errors.append(f"{prefix}.name must be unique")
            else:
                names.add(name)
            if probe.get("status") == "PASS" and not _text(probe.get("result")):
                errors.append(f"{prefix}.result is required when status is PASS")

    native = value.get("native_execution")
    _check(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is {native['status']}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_smoke(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("PACKAGE_SMOKE_PROBE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGE_SMOKE_PROBE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
