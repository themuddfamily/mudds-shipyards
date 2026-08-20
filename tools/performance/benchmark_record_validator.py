#!/usr/bin/env python3
"""Renderer-independent acceptance check for a production benchmark record.

This tool deliberately consumes the JSON emitted by ``benchmark_runner.gd``;
it never starts Godot and never treats a software-renderer result as native
hardware evidence.  It is useful after a native run to make the budget and
provenance decision reproducible in CI or in a release evidence bundle.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


REPORT_KIND = "keths_performance_benchmark"
SCHEMA_VERSION = 1
SCENARIOS = {"station_embodied_route", "nearby_sector_ship_flight_route"}
NATIVE_METRIC_FIELDS = {
    "frame_time_ms": "milliseconds",
    "gpu_frame_time_ms": "milliseconds",
    "ram_bytes": "bytes",
    "vram_bytes": "bytes",
    "draw_calls": "count",
}


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _summary_errors(label: str, summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return [f"{label} must be an object"]
    required = ("count", "p50", "p95", "p99", "max")
    if any(key not in summary for key in required):
        return [f"{label} is missing one of {required}"]
    values = [summary[key] for key in required]
    if not all(_number(value) for value in values) or int(summary["count"]) < 2:
        return [f"{label} has invalid count or percentile values"]
    if not (0 <= summary["p50"] <= summary["p95"] <= summary["p99"] <= summary["max"]):
        return [f"{label} percentiles are not monotonic"]
    return []


def _native_metric_errors(metrics: Any) -> list[str]:
    """Validate evidence shape while allowing counters to remain unavailable."""
    errors: list[str] = []
    if not isinstance(metrics, dict):
        return ["native_metrics must be an object"]
    for name, unit in NATIVE_METRIC_FIELDS.items():
        entry = metrics.get(name)
        if not isinstance(entry, dict):
            errors.append(f"native_metrics.{name} must be an object")
            continue
        available = entry.get("available")
        value = entry.get("value")
        if not isinstance(available, bool):
            errors.append(f"native_metrics.{name}.available must be boolean")
        if entry.get("unit") != unit:
            errors.append(f"native_metrics.{name}.unit must be {unit}")
        if available is True and (not _number(value) or value < 0):
            errors.append(f"native_metrics.{name}.value must be non-negative when available")
        elif available is not True and value is not None:
            errors.append(f"native_metrics.{name}.value must be null when unavailable")
        if not isinstance(entry.get("source"), str) or not entry["source"].strip():
            errors.append(f"native_metrics.{name}.source is required")
    return errors


def validate_record(report: dict[str, Any], target: dict[str, Any] | None = None) -> list[str]:
    """Return blocking acceptance errors; an empty list means the record passes."""
    errors: list[str] = []
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if report.get("report_kind") != REPORT_KIND:
        errors.append("report_kind is not a production benchmark record")

    source = report.get("source")
    if not isinstance(source, dict) or not source.get("git_sha"):
        errors.append("source.git_sha is required")
    if not isinstance(source, dict) or source.get("git_dirty") is not False:
        errors.append("source.git_dirty must be false")

    representation = report.get("representativeness")
    if not isinstance(representation, dict) or representation.get("representative_pass") is not True:
        errors.append("representativeness.representative_pass must be true")
    if isinstance(representation, dict) and representation.get("performance_budget_pass") is False:
        errors.append("record reports performance_budget_pass=false")

    configuration = report.get("configuration")
    if not isinstance(configuration, dict) or configuration.get("smoke_run") is not False:
        errors.append("configuration.smoke_run must be false")

    errors.extend(_native_metric_errors(report.get("native_metrics")))

    unavailable = report.get("unavailable_metrics")
    for metric in ("gpu_frame_time_ms", "vram_bytes"):
        entry = unavailable.get(metric) if isinstance(unavailable, dict) else None
        if not isinstance(entry, dict) or entry.get("available") is not True or not _number(entry.get("value")):
            errors.append(f"{metric} must contain a measured native value")

    scenarios = report.get("scenarios")
    if not isinstance(scenarios, list) or {item.get("name") for item in scenarios if isinstance(item, dict)} != SCENARIOS:
        errors.append("exactly the two production benchmark scenarios are required")
        scenarios = []
    scenario_values: list[dict[str, Any]] = []
    for scenario in scenarios:
        if not isinstance(scenario, dict):
            errors.append("scenario entries must be objects")
            continue
        name = scenario.get("name", "unknown")
        if scenario.get("completed") is not True:
            errors.append(f"scenario {name} did not complete")
        errors.extend(_summary_errors(f"scenario {name} frame_delta_ms", scenario.get("frame_delta_ms")))
        ram = scenario.get("ram")
        if not isinstance(ram, dict) or not _number(ram.get("static_peak_bytes")):
            errors.append(f"scenario {name} static_peak_bytes is required")
        else:
            scenario_values.append(scenario)

    selected_target = target if target is not None else report.get("target_profile")
    budgets = selected_target.get("budgets") if isinstance(selected_target, dict) else None
    frame_budget = budgets.get("frame_time_ms") if isinstance(budgets, dict) else None
    if not isinstance(frame_budget, dict):
        errors.append("target budgets.frame_time_ms is required")
    else:
        for key in ("p95", "p99", "max"):
            if not _number(frame_budget.get(key)) or frame_budget[key] <= 0:
                errors.append(f"target budgets.frame_time_ms.{key} must be positive")
    ram_budget = budgets.get("peak_working_set_bytes") if isinstance(budgets, dict) else None
    if not _number(ram_budget) or ram_budget <= 0:
        errors.append("target budgets.peak_working_set_bytes must be positive")

    if isinstance(frame_budget, dict) and all(_number(frame_budget.get(key)) for key in ("p95", "p99", "max")):
        for scenario in scenario_values:
            summary = scenario["frame_delta_ms"]
            for key in ("p95", "p99", "max"):
                if summary[key] > frame_budget[key]:
                    errors.append(f"scenario {scenario['name']} {key} exceeds budget")
    if _number(ram_budget):
        for scenario in scenario_values:
            if scenario["ram"]["static_peak_bytes"] > ram_budget:
                errors.append(f"scenario {scenario['name']} peak working set exceeds budget")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("record", type=Path)
    parser.add_argument("--target", type=Path, help="optional target profile with budgets")
    args = parser.parse_args()
    report = json.loads(args.record.read_text(encoding="utf-8"))
    target = json.loads(args.target.read_text(encoding="utf-8")) if args.target else None
    errors = validate_record(report, target)
    if errors:
        print("PERFORMANCE_RECORD_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("PERFORMANCE_RECORD_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
