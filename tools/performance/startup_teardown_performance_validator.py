#!/usr/bin/env python3
"""Fail-closed validator for native startup/load/teardown evidence.

The measurements are supplied by a native Windows harness.  This module only
validates the report; it never launches Godot and never promotes a software
renderer result to representative performance evidence.  Startup, load,
teardown, and long-session growth are represented as percentile summaries so
the release decision cannot be based on a single unusually good run.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


REPORT_KIND = "keths_startup_teardown_performance"
SCHEMA_VERSION = 1
SUMMARY_FIELDS = ("startup_ms", "load_ms", "teardown_ms", "long_session_growth_bytes")


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _summary_errors(label: str, value: Any) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    required = ("count", "p50", "p95", "p99", "max")
    missing = tuple(key for key in required if key not in value)
    if missing:
        return [f"{label} is missing one of {required}"]
    if not isinstance(value["count"], int) or isinstance(value["count"], bool) or value["count"] < 2:
        return [f"{label}.count must be an integer >= 2"]
    if not all(_number(value[key]) and value[key] >= 0 for key in required[1:]):
        return [f"{label} percentile values must be finite and non-negative"]
    if not value["p50"] <= value["p95"] <= value["p99"] <= value["max"]:
        return [f"{label} percentiles are not monotonic"]
    return []


def validate_report(report: Any, target: Any | None = None) -> list[str]:
    """Return blocking errors; an empty list accepts the native report."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return ["report must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if report.get("report_kind") != REPORT_KIND:
        errors.append("report_kind is not startup/teardown performance evidence")

    native = report.get("native_evidence")
    if not isinstance(native, dict) or native.get("available") is not True:
        errors.append("native_evidence.available must be true")
    else:
        if native.get("platform") != "windows-x86_64":
            errors.append("native_evidence.platform must be windows-x86_64")
        if native.get("software_renderer") is not False:
            errors.append("native_evidence.software_renderer must be false")
        if not isinstance(native.get("hardware"), str) or not native["hardware"].strip():
            errors.append("native_evidence.hardware is required")
        if not isinstance(native.get("os_build"), str) or not native["os_build"].strip():
            errors.append("native_evidence.os_build is required")

    source = report.get("source")
    if not isinstance(source, dict) or not isinstance(source.get("git_sha"), str) or not source["git_sha"].strip():
        errors.append("source.git_sha is required")
    if not isinstance(source, dict) or source.get("git_dirty") is not False:
        errors.append("source.git_dirty must be false")

    provenance = report.get("measurement_provenance")
    if not isinstance(provenance, dict):
        errors.append("measurement_provenance is required")
    else:
        for key in ("harness", "capture_id"):
            if not isinstance(provenance.get(key), str) or not provenance[key].strip():
                errors.append(f"measurement_provenance.{key} is required")

    duration = report.get("long_session_seconds")
    if not _number(duration) or duration <= 0:
        errors.append("long_session_seconds must be positive")
    warmup = report.get("warmup_seconds")
    if not _number(warmup) or warmup < 0:
        errors.append("warmup_seconds must be finite and non-negative")
    if _number(duration) and _number(warmup) and warmup >= duration:
        errors.append("warmup_seconds must be less than long_session_seconds")

    summaries = report.get("summaries")
    if not isinstance(summaries, dict):
        errors.append("summaries must be an object")
        summaries = {}
    for name in SUMMARY_FIELDS:
        errors.extend(_summary_errors(f"summaries.{name}", summaries.get(name)))

    selected = target if target is not None else report.get("target_profile")
    budgets = selected.get("budgets") if isinstance(selected, dict) else None
    if not isinstance(budgets, dict):
        errors.append("target budgets are required")
        budgets = {}
    for key in ("startup_p95_ms", "startup_p99_ms", "load_p95_ms", "load_p99_ms", "teardown_p95_ms", "teardown_p99_ms", "max_long_session_growth_bytes"):
        if not _number(budgets.get(key)) or budgets[key] < 0:
            errors.append(f"target budgets.{key} must be non-negative")

    checks = (
        ("startup_ms", "startup_p95_ms", "p95"),
        ("startup_ms", "startup_p99_ms", "p99"),
        ("load_ms", "load_p95_ms", "p95"),
        ("load_ms", "load_p99_ms", "p99"),
        ("teardown_ms", "teardown_p95_ms", "p95"),
        ("teardown_ms", "teardown_p99_ms", "p99"),
        ("long_session_growth_bytes", "max_long_session_growth_bytes", "p99"),
    )
    for summary_name, budget_name, percentile in checks:
        summary = summaries.get(summary_name)
        budget = budgets.get(budget_name)
        if isinstance(summary, dict) and _number(budget) and summary[percentile] > budget:
            errors.append(f"summaries.{summary_name}.{percentile} exceeds budget")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--target", type=Path)
    args = parser.parse_args()
    try:
        report = json.loads(args.report.read_text(encoding="utf-8"))
        target = json.loads(args.target.read_text(encoding="utf-8")) if args.target else None
        errors = validate_report(report, target)
    except (OSError, json.JSONDecodeError, TypeError) as exc:
        print(f"STARTUP_TEARDOWN_EVIDENCE_INVALID: {exc}")
        return 1
    if errors:
        print("STARTUP_TEARDOWN_EVIDENCE_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("STARTUP_TEARDOWN_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
