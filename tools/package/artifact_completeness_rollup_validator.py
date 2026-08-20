#!/usr/bin/env python3
"""Validate completeness of a recorded package artifact evidence chain."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
STATES = {"PASS", "FAIL", "NOT_RUN", "UNKNOWN"}
REQUIRED_COMPONENTS = ("build", "source", "package", "runtime", "legal")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _status(record: Any, label: str, errors: list[str]) -> None:
    if not isinstance(record, dict):
        errors.append(f"{label} must be an object")
        return
    state = record.get("status")
    if state not in STATES:
        errors.append(f"{label}.status is invalid")
        return
    if state == "PASS" and not _text(record.get("evidence")):
        errors.append(f"{label}.evidence is required when status is PASS")
    if state in {"NOT_RUN", "UNKNOWN"} and record.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when status is {state}")


def validate_completeness(value: Any, label: str = "completeness") -> list[str]:
    """Return violations; an empty list means the completeness rollup is valid."""
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "artifact_label"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")

    components = value.get("components")
    if not isinstance(components, dict):
        errors.append(f"{label}.components must be an object")
        components = {}
    for component in REQUIRED_COMPONENTS:
        if component not in components:
            errors.append(f"{label}.components.{component} is required")
        else:
            _status(components[component], f"{label}.components.{component}", errors)
    unknown = set(components) - set(REQUIRED_COMPONENTS)
    if unknown:
        errors.append(f"{label}.components contains unknown component(s): {', '.join(sorted(unknown))}")

    accounted = value.get("accounted_files")
    if not isinstance(accounted, int) or accounted < 0:
        errors.append(f"{label}.accounted_files must be a non-negative integer")
    if value.get("unaccounted_files") != 0:
        errors.append(f"{label}.unaccounted_files must be 0")
    if value.get("complete") is not True:
        errors.append(f"{label}.complete must be true")

    native = value.get("native_execution")
    _status(native, f"{label}.native_execution", errors)
    if isinstance(native, dict) and native.get("status") in {"NOT_RUN", "UNKNOWN"}:
        for key in ("platform", "hardware", "evidence_path"):
            if native.get(key) is not None:
                errors.append(f"{label}.native_execution.{key} must be null when status is {native['status']}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    args = parser.parse_args(argv)
    errors = validate_completeness(json.loads(args.record.read_text(encoding="utf-8")))
    if errors:
        print("ARTIFACT_COMPLETENESS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("ARTIFACT_COMPLETENESS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
