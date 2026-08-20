#!/usr/bin/env python3
"""Validate before/after evidence for a visual optimization.

This is an evidence gate, not an image-quality judge.  It makes each claimed
optimization traceable to paired captures, a stable viewpoint, a declared
pixel-delta measurement, and a performance measurement with provenance.  The
manual inspection state deliberately cannot be used to claim approval.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
from typing import Any

SCHEMA = "visual_optimization_manifest_v1"
HUMAN_STATUSES = {"pending", "not_performed", "inspected"}
FORBIDDEN_HUMAN_STATUSES = {"approved", "pass", "signed_off", "complete"}
PIXEL_METRICS = {"mean_absolute_error", "max_absolute_error", "changed_pixel_ratio"}
PERFORMANCE_DIRECTIONS = {"lower_is_better", "higher_is_better"}


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def _required_text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(manifest_path: Path) -> list[str]:
    """Return blocking errors; an empty list means evidence is structurally ready."""
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]

    errors: list[str] = []
    required = ("schema", "human_inspection_status", "reviewer_required", "optimizations")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    status = data["human_inspection_status"]
    if status in FORBIDDEN_HUMAN_STATUSES:
        errors.append("human_inspection_status cannot claim approval")
    if status not in HUMAN_STATUSES:
        errors.append("human_inspection_status must be pending, not_performed, or inspected")
    if not _required_text(data["reviewer_required"]):
        errors.append("reviewer_required must identify the manual reviewer role")

    optimizations = data["optimizations"]
    if not isinstance(optimizations, list) or not optimizations:
        errors.append("optimizations must contain at least one optimization")
        return errors
    seen: set[str] = set()
    for index, item in enumerate(optimizations):
        prefix = f"optimization[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = item.get("id")
        if not _required_text(ident) or ident in seen:
            errors.append(f"{prefix}: id is missing or duplicated")
        elif ident:
            seen.add(ident)
        viewpoint = item.get("viewpoint")
        if not _required_text(viewpoint):
            errors.append(f"{prefix}: viewpoint is required and must be stable")

        captures = item.get("captures")
        if not isinstance(captures, dict) or set(captures) != {"before", "after"}:
            errors.append(f"{prefix}: captures must contain before and after")
        else:
            capture_paths: set[str] = set()
            for phase in ("before", "after"):
                capture = captures[phase]
                if not isinstance(capture, dict):
                    errors.append(f"{prefix} {phase} capture must be an object")
                    continue
                relative = capture.get("path")
                if not _required_text(relative) or relative in capture_paths:
                    errors.append(f"{prefix} {phase}: capture path is missing or duplicated")
                    continue
                capture_paths.add(relative)
                path = manifest_path.parent / relative
                if not path.is_file():
                    errors.append(f"{prefix} {phase}: capture not found: {path}")
                    continue
                recorded = capture.get("sha256")
                if not isinstance(recorded, str) or len(recorded) != 64:
                    errors.append(f"{prefix} {phase}: sha256 must be a 64-character digest")
                elif _sha256(path) != recorded:
                    errors.append(f"{prefix} {phase}: SHA-256 does not match manifest")

        delta = item.get("pixel_delta")
        if not isinstance(delta, dict):
            errors.append(f"{prefix}: pixel_delta is required")
        else:
            metric = delta.get("metric")
            if metric not in PIXEL_METRICS:
                errors.append(f"{prefix}: pixel_delta.metric is unsupported")
            if not _number(delta.get("value")) or delta["value"] < 0:
                errors.append(f"{prefix}: pixel_delta.value must be a non-negative number")
            if not _required_text(delta.get("method")):
                errors.append(f"{prefix}: pixel_delta.method is required")
            if metric == "changed_pixel_ratio" and _number(delta.get("value")) and not 0 <= delta["value"] <= 1:
                errors.append(f"{prefix}: changed_pixel_ratio must be between 0 and 1")

        performance = item.get("performance")
        if not isinstance(performance, dict):
            errors.append(f"{prefix}: performance is required")
            continue
        if not _required_text(performance.get("metric")) or not _required_text(performance.get("unit")):
            errors.append(f"{prefix}: performance metric and unit are required")
        direction = performance.get("direction")
        if direction not in PERFORMANCE_DIRECTIONS:
            errors.append(f"{prefix}: performance.direction must declare the better direction")
        before = performance.get("before")
        after = performance.get("after")
        if not _number(before) or not _number(after):
            errors.append(f"{prefix}: performance before and after must be finite numbers")
        elif (direction == "lower_is_better" and after >= before) or (direction == "higher_is_better" and after <= before):
            errors.append(f"{prefix}: performance does not improve in the declared direction")
        provenance = performance.get("provenance")
        if not isinstance(provenance, dict):
            errors.append(f"{prefix}: performance.provenance is required")
        else:
            for key in ("source", "command", "hardware", "captured_at"):
                if not _required_text(provenance.get(key)):
                    errors.append(f"{prefix}: provenance.{key} is required")
    return errors


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"VISUAL_OPTIMIZATION_MANIFEST_FAILED: {error}")
        return 1
    print(f"VISUAL_OPTIMIZATION_MANIFEST_READY: {args.manifest} (manual inspection remains required)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
