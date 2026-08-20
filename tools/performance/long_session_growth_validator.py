#!/usr/bin/env python3
"""Fail-closed validator for native long-session performance evidence.

The game does not manufacture native measurements.  A Windows harness supplies
this report after a representative soak; this module checks its provenance,
percentile summaries, memory/VRAM growth, startup time, and audio voices.  It
does not launch Godot or treat a software renderer as native evidence.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


REPORT_KIND = "keths_long_session_performance"
SCHEMA_VERSION = 1
SUMMARY_FIELDS = ("frame_time_ms", "gpu_time_ms", "ram_bytes", "vram_bytes", "audio_voices")


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value))


def _summary_errors(label: str, value: Any) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    required = ("count", "p50", "p95", "p99", "max")
    if any(key not in value for key in required):
        return [f"{label} is missing one of {required}"]
    if not isinstance(value["count"], int) or isinstance(value["count"], bool) or value["count"] < 2:
        return [f"{label}.count must be an integer >= 2"]
    if not all(_number(value[key]) and value[key] >= 0 for key in required[1:]):
        return [f"{label} percentile values must be finite and non-negative"]
    if not (value["p50"] <= value["p95"] <= value["p99"] <= value["max"]):
        return [f"{label} percentiles are not monotonic"]
    return []


def _metric_value_errors(label: str, value: Any) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    if value.get("unit") not in {"milliseconds", "bytes", "count"}:
        return [f"{label}.unit is invalid"]
    if not _number(value.get("baseline")) or not _number(value.get("end")) or not _number(value.get("peak")):
        return [f"{label} requires finite baseline, end, and peak"]
    if min(value["baseline"], value["end"], value["peak"]) < 0:
        return [f"{label} values must be non-negative"]
    if value["peak"] < value["end"]:
        return [f"{label}.peak must be >= end"]
    return []


def validate_report(report: Any, target: Any | None = None) -> list[str]:
    """Return blocking errors; an empty list is accepted native evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return ["report must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if report.get("report_kind") != REPORT_KIND:
        errors.append("report_kind is not long-session performance evidence")

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
    source = report.get("source")
    if not isinstance(source, dict) or not isinstance(source.get("git_sha"), str) or not source["git_sha"].strip():
        errors.append("source.git_sha is required")
    if not isinstance(source, dict) or source.get("git_dirty") is not False:
        errors.append("source.git_dirty must be false")

    duration = report.get("duration_seconds")
    cycles = report.get("reentry_cycles")
    if not _number(duration) or duration <= 0:
        errors.append("duration_seconds must be positive")
    if not isinstance(cycles, int) or isinstance(cycles, bool) or cycles < 1:
        errors.append("reentry_cycles must be a positive integer")

    summaries = report.get("summaries")
    if not isinstance(summaries, dict):
        errors.append("summaries must be an object")
        summaries = {}
    for name in SUMMARY_FIELDS:
        errors.extend(_summary_errors(f"summaries.{name}", summaries.get(name)))

    growth = report.get("growth")
    if not isinstance(growth, dict):
        errors.append("growth must be an object")
        growth = {}
    for name, unit in (("ram_bytes", "bytes"), ("vram_bytes", "bytes")):
        entry = growth.get(name)
        errors.extend(_metric_value_errors(f"growth.{name}", entry))
        if isinstance(entry, dict) and entry.get("unit") != unit:
            errors.append(f"growth.{name}.unit must be {unit}")

    startup = report.get("startup_time_ms")
    if not _number(startup) or startup < 0:
        errors.append("startup_time_ms must be finite and non-negative")
    voice = report.get("voice_memory_bytes")
    if not _number(voice) or voice < 0:
        errors.append("voice_memory_bytes must be finite and non-negative")

    selected = target if target is not None else report.get("target_profile")
    budgets = selected.get("budgets") if isinstance(selected, dict) else None
    if not isinstance(budgets, dict):
        errors.append("target budgets are required")
        budgets = {}
    for key in ("frame_p95_ms", "frame_p99_ms", "gpu_p95_ms", "startup_ms", "max_ram_growth_bytes", "max_vram_growth_bytes", "max_audio_voices", "max_voice_memory_bytes"):
        if not _number(budgets.get(key)) or budgets[key] < 0:
            errors.append(f"target budgets.{key} must be non-negative")

    if isinstance(summaries.get("frame_time_ms"), dict) and _number(budgets.get("frame_p95_ms")):
        if summaries["frame_time_ms"]["p95"] > budgets["frame_p95_ms"]:
            errors.append("frame_time_ms.p95 exceeds budget")
    if isinstance(summaries.get("frame_time_ms"), dict) and _number(budgets.get("frame_p99_ms")):
        if summaries["frame_time_ms"]["p99"] > budgets["frame_p99_ms"]:
            errors.append("frame_time_ms.p99 exceeds budget")
    if isinstance(summaries.get("gpu_time_ms"), dict) and _number(budgets.get("gpu_p95_ms")):
        if summaries["gpu_time_ms"]["p95"] > budgets["gpu_p95_ms"]:
            errors.append("gpu_time_ms.p95 exceeds budget")
    if _number(startup) and _number(budgets.get("startup_ms")) and startup > budgets["startup_ms"]:
        errors.append("startup_time_ms exceeds budget")
    for name, budget_key in (("ram_bytes", "max_ram_growth_bytes"), ("vram_bytes", "max_vram_growth_bytes")):
        entry = growth.get(name)
        if isinstance(entry, dict) and _number(budgets.get(budget_key)):
            if entry["peak"] - entry["baseline"] > budgets[budget_key]:
                errors.append(f"growth.{name} exceeds budget")
    if isinstance(summaries.get("audio_voices"), dict) and _number(budgets.get("max_audio_voices")):
        if summaries["audio_voices"]["max"] > budgets["max_audio_voices"]:
            errors.append("audio_voices.max exceeds budget")
    if _number(voice) and _number(budgets.get("max_voice_memory_bytes")) and voice > budgets["max_voice_memory_bytes"]:
        errors.append("voice_memory_bytes exceeds budget")
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
        print(f"LONG_SESSION_EVIDENCE_INVALID: {exc}")
        return 1
    if errors:
        print("LONG_SESSION_EVIDENCE_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("LONG_SESSION_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
