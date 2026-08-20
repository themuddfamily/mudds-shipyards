#!/usr/bin/env python3
"""Validate the cross-feature performance budget evidence rollup.

The rollup is only a join: geometry, renderer/audio, startup/teardown, LOD,
and native benchmark reports remain authoritative in their own schemas.  A
missing report, missing provenance, unavailable metric, or mismatched source
identity keeps the gate closed.  This module never measures the host and
never turns headless output into native evidence.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import geometry_package_evidence_validator as geometry_package
import lod_streaming_budget_validator as lod
import native_benchmark_record_collector as native_collector
import renderer_audio_census_evidence_validator as renderer_audio
import startup_teardown_performance_validator as startup


SCHEMA_VERSION = 1
REPORT_KIND = "performance_budget_rollup"
_COMMIT = re.compile(r"^[0-9a-f]{7,64}$")
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_REQUIRED_REPORTS = (
    "geometry_evidence",
    "renderer_audio_evidence",
    "startup_teardown",
    "lod_streaming",
    "native_metrics",
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _native_metric_errors(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return ["native_metrics must be an object"]
    for name, unit in native_collector.METRIC_FIELDS.items():
        entry = value.get(name)
        label = f"native_metrics.{name}"
        if not isinstance(entry, dict):
            errors.append(f"{label} must be an object")
            continue
        if entry.get("available") is not True:
            errors.append(f"{label}.available must be true")
        if entry.get("unit") != unit:
            errors.append(f"{label}.unit must be {unit}")
        if not isinstance(entry.get("value"), (int, float)) or isinstance(entry.get("value"), bool) or entry["value"] < 0:
            errors.append(f"{label}.value must be a non-negative number")
        if not _text(entry.get("source")):
            errors.append(f"{label}.source is required")
    return errors


def _target(value: Any, key: str) -> Any:
    return value.get(key) if isinstance(value, dict) else None


def validate_rollup(value: Any, target: Any | None = None) -> list[str]:
    """Return blocking errors; an empty list means all evidence is joined."""
    if not isinstance(value, dict):
        return ["rollup must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if value.get("report_kind") != REPORT_KIND:
        errors.append(f"report_kind must be {REPORT_KIND}")

    provenance = value.get("provenance")
    if not isinstance(provenance, dict):
        errors.append("provenance must be an object")
        provenance = {}
    for key in ("source_commit", "platform", "capture_id", "artifact_sha256"):
        if not _text(provenance.get(key)):
            errors.append(f"provenance.{key} is required")
    if _text(provenance.get("source_commit")) and not _COMMIT.fullmatch(provenance["source_commit"]):
        errors.append("provenance.source_commit must be a lowercase git revision")
    if _text(provenance.get("artifact_sha256")) and not _SHA256.fullmatch(provenance["artifact_sha256"]):
        errors.append("provenance.artifact_sha256 must be a lowercase SHA-256")
    if provenance.get("platform") not in {"windows-x86_64", "windows-arm64"}:
        errors.append("provenance.platform must be a Windows platform")

    reports = value.get("reports")
    if not isinstance(reports, dict):
        return errors + ["reports must be an object"]
    missing = [name for name in _REQUIRED_REPORTS if name not in reports]
    errors.extend(f"reports.{name} is required" for name in missing)

    geometry_report = reports.get("geometry_evidence")
    if isinstance(geometry_report, dict):
        errors.extend(geometry_package.validate_manifest(geometry_report))
    renderer_report = reports.get("renderer_audio_evidence")
    if isinstance(renderer_report, dict):
        errors.extend(renderer_audio.validate_manifest(renderer_report))
    startup_report = reports.get("startup_teardown")
    if isinstance(startup_report, dict):
        errors.extend(startup.validate_report(startup_report, _target(target, "startup_target")))
    lod_report = reports.get("lod_streaming")
    if isinstance(lod_report, dict):
        errors.extend(lod.validate_budget(lod_report, _target(target, "lod_target") or {}))
    errors.extend(_native_metric_errors(reports.get("native_metrics")))

    # Every participating record must identify the same source build.  This
    # prevents a green rollup assembled from unrelated captures.
    commits: dict[str, Any] = {"rollup": provenance.get("source_commit")}
    if isinstance(geometry_report, dict):
        commits["geometry"] = geometry_report.get("package", {}).get("source_commit")
    if isinstance(renderer_report, dict):
        commits["renderer_audio"] = renderer_report.get("package", {}).get("source_commit")
    if isinstance(startup_report, dict):
        commits["startup"] = startup_report.get("source", {}).get("git_sha")
    for name, commit in commits.items():
        if _text(provenance.get("source_commit")) and commit != provenance["source_commit"]:
            errors.append(f"provenance.source_commit must match {name} source commit")

    if isinstance(geometry_report, dict):
        package = geometry_report.get("package", {})
        if package.get("platform") != provenance.get("platform"):
            errors.append("provenance.platform must match geometry package platform")
        if package.get("artifact_sha256") != provenance.get("artifact_sha256"):
            errors.append("provenance.artifact_sha256 must match geometry package artifact")
    if isinstance(renderer_report, dict):
        package = renderer_report.get("package", {})
        if package.get("platform") != provenance.get("platform"):
            errors.append("provenance.platform must match renderer/audio package platform")
        if package.get("artifact_sha256") != provenance.get("artifact_sha256"):
            errors.append("provenance.artifact_sha256 must match renderer/audio package artifact")
    return errors


def summarize(value: dict[str, Any]) -> dict[str, Any]:
    """Expose joined headline values without weakening validation."""
    reports = value["reports"]
    scene = reports["geometry_evidence"]["scene_census"]
    native = reports["native_metrics"]
    lod_report = reports["lod_streaming"]
    return {
        "triangles": scene["total_triangles"],
        "draw_calls": native["draw_calls"]["value"],
        "frame_time_ms": native["frame_time_ms"]["value"],
        "vram_bytes": native["vram_bytes"]["value"],
        "resident_tiles": lod_report["tiles"]["resident_count"],
        "source_commit": value["provenance"]["source_commit"],
        "capture_id": value["provenance"]["capture_id"],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("rollup", type=Path)
    parser.add_argument("--target", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.rollup.read_text(encoding="utf-8"))
        target = json.loads(args.target.read_text(encoding="utf-8")) if args.target else None
        errors = validate_rollup(value, target)
    except (OSError, json.JSONDecodeError, TypeError) as exc:
        print(f"PERFORMANCE_BUDGET_ROLLUP_INVALID: {exc}")
        return 1
    if errors:
        print("PERFORMANCE_BUDGET_ROLLUP_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(json.dumps(summarize(value), indent=2, sort_keys=True))
    print("PERFORMANCE_BUDGET_ROLLUP_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
