#!/usr/bin/env python3
"""Validate one geometry/audio census joined to native hardware evidence.

The geometry and audio census reports are deterministic scene/resource
measurements.  Native draw, GPU, VRAM, mixer and audio-memory measurements
must come from the same packaged Windows run.  This gate only validates the
machine-readable join; it never probes the host or promotes software metrics.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import audio_voice_budget_validator as audio
import geometry_delta_validator as geometry


SCHEMA_VERSION = 1
REPORT_KIND = "renderer_audio_census_evidence"
NATIVE_METRICS = {
    "draw_calls": "count",
    "gpu_frame_time_ms": "milliseconds",
    "vram_bytes": "bytes",
    "native_mixer_voice_count": "count",
    "native_audio_memory_bytes": "bytes",
}
SOFTWARE_TOKENS = (
    "llvmpipe", "softpipe", "lavapipe", "swiftshader",
    "software rasterizer", "software renderer",
)
_SHA256 = re.compile(r"^[0-9a-f]{64}$")
_COMMIT = re.compile(r"^[0-9a-f]{7,64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _nonnegative(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0


def _software_reason(native: dict[str, Any]) -> str | None:
    if native.get("software_renderer") is True:
        return "native_evidence.software_renderer=true"
    identity = " ".join(
        str(native[key])
        for key in ("renderer", "adapter", "gpu", "device", "driver", "renderer_name")
        if isinstance(native.get(key), str)
    ).lower()
    for token in SOFTWARE_TOKENS:
        if token in identity:
            return f"native renderer identity contains {token!r}"
    return None


def _native_errors(native: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(native, dict):
        return ["native_evidence must be an object"]
    reason = _software_reason(native)
    if reason:
        errors.append(f"software renderer is not native evidence: {reason}")
    if native.get("available") is not True:
        errors.append("native_evidence.available must be true")
    if native.get("software_renderer") is not False:
        errors.append("native_evidence.software_renderer must be false")
    if native.get("platform") not in {"windows-x86_64", "windows-arm64"}:
        errors.append("native_evidence.platform must be a Windows platform")
    for key in ("source", "source_commit", "renderer", "hardware"):
        if not _text(native.get(key)):
            errors.append(f"native_evidence.{key} is required")
    metrics = native.get("metrics")
    if not isinstance(metrics, dict):
        return errors + ["native_evidence.metrics must be an object"]
    for name, unit in NATIVE_METRICS.items():
        entry = metrics.get(name)
        label = f"native_evidence.metrics.{name}"
        if not isinstance(entry, dict):
            errors.append(f"{label} must be an object")
            continue
        if entry.get("available") is not True:
            errors.append(f"{label}.available must be true")
        if entry.get("unit") != unit:
            errors.append(f"{label}.unit must be {unit}")
        if not _nonnegative(entry.get("value")):
            errors.append(f"{label}.value must be a non-negative number")
        if not _text(entry.get("source")):
            errors.append(f"{label}.source is required")
    return errors


def validate_manifest(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the join is valid."""
    if not isinstance(value, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if value.get("report_kind") != REPORT_KIND:
        errors.append(f"report_kind must be {REPORT_KIND}")
    package = value.get("package")
    if not isinstance(package, dict):
        errors.append("package must be an object")
        package = {}
    for key in ("artifact_sha256", "source_commit", "platform", "renderer", "resolution", "profile"):
        if not _text(package.get(key)):
            errors.append(f"package.{key} is required")
    if _text(package.get("artifact_sha256")) and not _SHA256.fullmatch(package["artifact_sha256"]):
        errors.append("package.artifact_sha256 must be a lowercase SHA-256")
    if _text(package.get("source_commit")) and not _COMMIT.fullmatch(package["source_commit"]):
        errors.append("package.source_commit must be a lowercase git revision")

    scene = value.get("scene_census")
    errors.extend(geometry.validate_report(scene, "scene_census"))
    if isinstance(scene, dict):
        if scene.get("source_commit") != package.get("source_commit"):
            errors.append("scene_census.source_commit must match package.source_commit")
        if scene.get("measurement_scope") != "packaged_scene":
            errors.append("scene_census.measurement_scope must be packaged_scene")

    audio_report = value.get("audio_census")
    errors.extend(audio.validate_report(audio_report, "audio_census"))
    if isinstance(audio_report, dict) and audio_report.get("source_commit") != package.get("source_commit"):
        errors.append("audio_census.source_commit must match package.source_commit")
    native = value.get("native_evidence")
    errors.extend(_native_errors(native))
    if isinstance(native, dict):
        if native.get("source_commit") != package.get("source_commit"):
            errors.append("native_evidence.source_commit must match package.source_commit")
        if native.get("platform") != package.get("platform"):
            errors.append("native_evidence.platform must match package.platform")
    return errors


def joined_metrics(value: dict[str, Any]) -> dict[str, Any]:
    """Return the four roadmap headline counters plus their native sources."""
    scene = value["scene_census"]
    census = value["audio_census"]
    totals = census["totals"]
    streams = census["retained_streams"]
    native = value["native_evidence"]["metrics"]
    return {
        "triangles": scene["total_triangles"],
        "lights": scene["lights"],
        "voices": totals["summed_max_polyphony_ceiling"],
        "bytes": streams["payload_bytes"],
        "native_provenance": {name: native[name]["source"] for name in NATIVE_METRICS},
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"RENDERER_AUDIO_CENSUS_INVALID: {exc}")
        return 1
    errors = validate_manifest(value)
    if errors:
        print("RENDERER_AUDIO_CENSUS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(json.dumps(joined_metrics(value), indent=2, sort_keys=True))
    print("RENDERER_AUDIO_CENSUS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
