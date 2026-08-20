#!/usr/bin/env python3
"""Validate metadata for a native audio capture and listening pass.

This tool checks the evidence contract only.  It never opens an audio device
and a valid manifest does not imply that anyone heard the mix.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
CAPTURE_STATUSES = {"CAPTURED", "NOT_RUN", "FAILED"}
LISTENING_STATUSES = {"PASS", "FAIL", "OUTSTANDING", "NOT_RUN"}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _unique_texts(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_manifest(manifest: Any, label: str = "manifest") -> list[str]:
    """Return fail-closed metadata and claim-boundary errors."""
    if not isinstance(manifest, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("capture_id", "build_label", "source_commit", "recorded_at_utc"):
        if not _text(manifest.get(key)):
            errors.append(f"{label}.{key} is required")

    recording = manifest.get("recording")
    if not isinstance(recording, dict):
        errors.append(f"{label}.recording must be an object")
        recording = {}
    if recording.get("backend") != "native_output":
        errors.append(f"{label}.recording.backend must be native_output")
    for key in ("device", "os", "gpu", "audio_driver"):
        if not _text(recording.get(key)):
            errors.append(f"{label}.recording.{key} is required")
    for key in ("sample_rate_hz", "channels"):
        if not _positive_int(recording.get(key)):
            errors.append(f"{label}.recording.{key} must be a positive integer")
    if not isinstance(recording.get("duration_seconds"), (int, float)) or isinstance(recording.get("duration_seconds"), bool) or recording.get("duration_seconds", 0) <= 0:
        errors.append(f"{label}.recording.duration_seconds must be positive")

    capture = manifest.get("capture")
    if not isinstance(capture, dict):
        errors.append(f"{label}.capture must be an object")
        capture = {}
    status = capture.get("status")
    if status not in CAPTURE_STATUSES:
        errors.append(f"{label}.capture.status is invalid")
    if status == "CAPTURED":
        if not _text(capture.get("artifact_path")):
            errors.append(f"{label}.capture.artifact_path is required for CAPTURED")
        digest = capture.get("sha256")
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            errors.append(f"{label}.capture.sha256 must be a lowercase 64-character digest for CAPTURED")
        if not _text(capture.get("evidence")):
            errors.append(f"{label}.capture.evidence is required for CAPTURED")
    elif not _text(capture.get("notes")):
        errors.append(f"{label}.capture.notes is required while capture is incomplete")

    scenarios = manifest.get("scenarios")
    if not _unique_texts(scenarios):
        errors.append(f"{label}.scenarios must be a non-empty unique array")
    else:
        required = {"station_rest", "combat", "return_or_reentry"}
        if not required.issubset(scenarios):
            errors.append(f"{label}.scenarios must cover station_rest, combat, and return_or_reentry")

    listening = manifest.get("listening")
    if not isinstance(listening, dict):
        errors.append(f"{label}.listening must be an object")
        listening = {}
    listening_status = listening.get("status")
    if listening_status not in LISTENING_STATUSES:
        errors.append(f"{label}.listening.status is invalid")
    if listening_status == "PASS":
        for key in ("reviewer", "device", "notes"):
            if not _text(listening.get(key)):
                errors.append(f"{label}.listening.{key} is required for PASS")
        for key in ("mix_levels", "speaker_positions"):
            if not _unique_texts(listening.get(key)):
                errors.append(f"{label}.listening.{key} must be a non-empty unique array for PASS")
        if capture.get("status") != "CAPTURED":
            errors.append(f"{label}.listening.PASS requires CAPTURED evidence")
        if listening.get("device") != recording.get("device"):
            errors.append(f"{label}.listening.device must match recording.device")
    elif listening_status in {"OUTSTANDING", "NOT_RUN"} and not _text(listening.get("notes")):
        errors.append(f"{label}.listening.notes is required while listening is incomplete")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("NATIVE_AUDIO_CAPTURE_MANIFEST_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("NATIVE_AUDIO_CAPTURE_MANIFEST_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
