#!/usr/bin/env python3
"""Validate native capture evidence without claiming a human visual sign-off.

The manifest is deliberately evidence-only.  It binds each image to a hash,
records the camera lock used for repeatable captures, and identifies the
native Windows build/GPU provenance.  ``human_review_status`` must remain
pending until a reviewer has inspected the captures in the target context.
"""

from __future__ import annotations

import hashlib
import json
import re
from pathlib import Path

SCHEMA = "native_capture_evidence_manifest_v1"
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
PENDING = {"pending", "not_performed"}


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def validate(manifest_path: Path) -> list[str]:
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    errors: list[str] = []
    required = ("schema", "human_review_status", "target", "camera_lock", "captures")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    if data["human_review_status"] not in PENDING:
        errors.append("human_review_status must remain pending or not_performed")

    target = data["target"]
    if not isinstance(target, dict):
        errors.append("target must be an object")
    else:
        if target.get("os") != "Windows":
            errors.append("target.os must be Windows")
        for key in ("architecture", "build_identity", "gpu", "driver"):
            if not _text(target.get(key)):
                errors.append(f"target.{key} is required for native provenance")
        if target.get("capture_method") != "native_windows":
            errors.append("target.capture_method must be native_windows")

    lock = data["camera_lock"]
    if not isinstance(lock, dict):
        errors.append("camera_lock must be an object")
    else:
        if lock.get("stable") is not True:
            errors.append("camera_lock.stable must be true")
        for key in ("position", "rotation", "fov", "projection"):
            if key not in lock:
                errors.append(f"camera_lock.{key} is required")
        if not _text(lock.get("profile")):
            errors.append("camera_lock.profile is required")

    captures = data["captures"]
    if not isinstance(captures, list) or not captures:
        errors.append("captures must contain at least one frame")
        return errors
    seen: set[str] = set()
    for capture in captures:
        if not isinstance(capture, dict):
            errors.append("each capture must be an object")
            continue
        name = capture.get("path")
        if not isinstance(name, str) or not name or name in seen:
            errors.append(f"capture path missing or duplicated: {name!r}")
            continue
        seen.add(name)
        path = (manifest_path.parent / name).resolve()
        if manifest_path.parent.resolve() not in path.parents:
            errors.append(f"{name}: capture path escapes manifest directory")
            continue
        if not path.is_file():
            errors.append(f"capture not found: {path}")
            continue
        recorded = capture.get("sha256")
        if not isinstance(recorded, str) or not SHA256.fullmatch(recorded):
            errors.append(f"{name}: sha256 must be a 64-character hexadecimal digest")
        elif sha256(path) != recorded.lower():
            errors.append(f"{name}: SHA-256 does not match manifest")
        if not _text(capture.get("viewpoint")):
            errors.append(f"{name}: viewpoint is required")
        if capture.get("camera_lock_profile") != lock.get("profile"):
            errors.append(f"{name}: camera_lock_profile does not match camera_lock.profile")
    return errors

