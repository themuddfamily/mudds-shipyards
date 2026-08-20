#!/usr/bin/env python3
"""Validate a packaged geometry census joined to native renderer evidence.

``geometry_census.gd`` supplies deterministic scene/resource counts, while a
native Windows run supplies the renderer-dependent measurements.  These are
different authorities and must be recorded together without allowing one to
stand in for the other.  This validator only checks an evidence manifest; it
does not launch Godot or infer native measurements from a software renderer.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import geometry_delta_validator as geometry


SCHEMA_VERSION = 1
REPORT_KIND = "packaged_geometry_evidence"
NATIVE_METRICS = {
    "frame_time_ms": "milliseconds",
    "gpu_frame_time_ms": "milliseconds",
    "ram_bytes": "bytes",
    "vram_bytes": "bytes",
    "draw_calls": "count",
}
SOFTWARE_TOKENS = (
    "llvmpipe", "softpipe", "lavapipe", "swiftshader",
    "software rasterizer", "software renderer",
)
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(_SHA256.fullmatch(value))


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value >= 0


def _software_reason(evidence: dict[str, Any]) -> str | None:
    if evidence.get("software_renderer") is True:
        return "native_evidence.software_renderer=true"
    identity: list[str] = []
    for key in ("renderer", "adapter", "gpu", "device", "driver", "renderer_name"):
        value = evidence.get(key)
        if isinstance(value, str):
            identity.append(value)
    text = " ".join(identity).lower()
    for token in SOFTWARE_TOKENS:
        if token in text:
            return f"native renderer identity contains {token!r}"
    return None


def _native_errors(evidence: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(evidence, dict):
        return ["native_evidence must be an object"]
    if evidence.get("available") is not True:
        errors.append("native_evidence.available must be true")
    if evidence.get("software_renderer") is not False:
        errors.append("native_evidence.software_renderer must be false")
    if evidence.get("platform") not in {"windows-x86_64", "windows-arm64"}:
        errors.append("native_evidence.platform must be a Windows platform")
    for key in ("source", "source_commit", "renderer", "hardware"):
        if not _text(evidence.get(key)):
            errors.append(f"native_evidence.{key} is required")
    metrics = evidence.get("metrics")
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
        if not _number(entry.get("value")):
            errors.append(f"{label}.value must be a non-negative number")
        if not _text(entry.get("source")):
            errors.append(f"{label}.source is required")
    return errors


def validate_manifest(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the joined record is valid."""
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
    if _text(package.get("artifact_sha256")) and not _sha(package["artifact_sha256"].lower()):
        errors.append("package.artifact_sha256 must be a lowercase SHA-256")
    if _text(package.get("source_commit")) and not re.fullmatch(r"[0-9a-f]{7,64}", package["source_commit"]):
        errors.append("package.source_commit must be a lowercase git revision")

    scene = value.get("scene_census")
    errors.extend(geometry.validate_report(scene, "scene_census"))
    if isinstance(scene, dict):
        if scene.get("source_commit") != package.get("source_commit"):
            errors.append("scene_census.source_commit must match package.source_commit")
        if scene.get("measurement_scope") != "packaged_scene":
            errors.append("scene_census.measurement_scope must be packaged_scene")

    native = value.get("native_evidence")
    reason = _software_reason(native) if isinstance(native, dict) else None
    if reason:
        errors.append(f"software renderer is not native evidence: {reason}")
    errors.extend(_native_errors(native))
    if isinstance(native, dict):
        if native.get("source_commit") != package.get("source_commit"):
            errors.append("native_evidence.source_commit must match package.source_commit")
        if native.get("platform") != package.get("platform"):
            errors.append("native_evidence.platform must match package.platform")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PACKAGED_GEOMETRY_EVIDENCE_INVALID: {exc}")
        return 1
    errors = validate_manifest(value)
    if errors:
        print("PACKAGED_GEOMETRY_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PACKAGED_GEOMETRY_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
