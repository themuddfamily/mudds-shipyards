#!/usr/bin/env python3
"""Fail-closed validator for renderer-independent geometry census deltas.

This compares two ``tools/geometry_census.gd`` schema-v2 reports.  It is
deliberately not a renderer benchmark: draw calls, GPU time, VRAM and frame
time remain unavailable until a native run supplies them.  A candidate must
also carry explicit authority and rendered-view review evidence; a smaller
number alone is not enough to accept a visual optimisation.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 2
SCENARIOS = {"station_resident", "cinder_loaded"}
METRICS = (
    "total_triangles",
    "total_mesh_instances",
    "total_surfaces",
    "unique_meshes",
    "bound_phase_unique_materials",
    "retained_reachable_unique_materials",
    "unique_shaders",
    "unique_textures",
    "texture_bytes",
    "lights",
    "shadow_lights",
    "particle_systems",
    "nodes",
)
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def validate_report(report: Any, label: str = "report") -> list[str]:
    """Return structural errors for one geometry census report."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if report.get("scenario") not in SCENARIOS:
        errors.append(f"{label}.scenario must be one of {sorted(SCENARIOS)}")
    if not _integer(report.get("loaded_instance_count")) or report.get("loaded_instance_count") not in (0, 1):
        errors.append(f"{label}.loaded_instance_count must be 0 or 1")
    fingerprint = report.get("measurement_fingerprint")
    if not isinstance(fingerprint, str) or not _SHA256.fullmatch(fingerprint):
        errors.append(f"{label}.measurement_fingerprint must be a lowercase SHA-256")
    for metric in METRICS:
        value = report.get(metric)
        if not _integer(value) or value < 0:
            errors.append(f"{label}.{metric} must be a non-negative integer")
    if not isinstance(report.get("buckets"), dict):
        errors.append(f"{label}.buckets must be an object")
    return errors


def validate_delta(
    baseline: Any,
    candidate: Any,
    budgets: dict[str, Any] | None = None,
) -> list[str]:
    """Return blocking errors for a candidate census delta.

    All renderer-independent cost metrics are monotonic.  ``budgets`` is
    optional, but when provided each declared metric is checked against it.
    """
    errors = validate_report(baseline, "baseline")
    errors.extend(validate_report(candidate, "candidate"))
    if errors or not isinstance(baseline, dict) or not isinstance(candidate, dict):
        return errors
    if baseline.get("scenario") != candidate.get("scenario"):
        errors.append("baseline and candidate scenarios must match")
    if baseline.get("loaded_instance_count") != candidate.get("loaded_instance_count"):
        errors.append("baseline and candidate loaded_instance_count must match")

    evidence = candidate.get("optimization_evidence")
    if not isinstance(evidence, dict) or evidence.get("authority_unchanged") is not True:
        errors.append("candidate optimization_evidence.authority_unchanged must be true")
    review = evidence.get("visual_review") if isinstance(evidence, dict) else None
    if not isinstance(review, dict) or review.get("status") != "pass":
        errors.append("candidate optimization_evidence.visual_review.status must be pass")
    elif not isinstance(review.get("viewpoints"), list) or not review["viewpoints"]:
        errors.append("candidate visual_review.viewpoints must be non-empty")

    reductions = 0
    for metric in METRICS:
        before, after = baseline[metric], candidate[metric]
        if after > before:
            errors.append(f"candidate {metric} regresses ({before} -> {after})")
        elif after < before:
            reductions += 1
    if reductions == 0:
        errors.append("candidate has no measured geometry/material reduction")

    if budgets is not None:
        if not isinstance(budgets, dict):
            errors.append("budgets must be an object")
        else:
            for metric, ceiling in budgets.items():
                if metric not in METRICS:
                    errors.append(f"budget names unknown metric {metric}")
                elif not _integer(ceiling) or ceiling < 0:
                    errors.append(f"budget {metric} must be a non-negative integer")
                elif candidate[metric] > ceiling:
                    errors.append(f"candidate {metric} exceeds budget ({candidate[metric]} > {ceiling})")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("baseline", type=Path)
    parser.add_argument("candidate", type=Path)
    parser.add_argument("--budgets", type=Path, help="optional JSON object of metric ceilings")
    args = parser.parse_args()
    baseline = json.loads(args.baseline.read_text(encoding="utf-8"))
    candidate = json.loads(args.candidate.read_text(encoding="utf-8"))
    budgets = json.loads(args.budgets.read_text(encoding="utf-8")) if args.budgets else None
    errors = validate_delta(baseline, candidate, budgets)
    if errors:
        print("GEOMETRY_DELTA_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("GEOMETRY_DELTA_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
