#!/usr/bin/env python3
"""Validate evidence for the player-led packaged flight-tuning pass.

This is an evidence-shape gate, not a playtest or readiness decision.  It
requires separate input, camera, and landing trials, preserves the metrics
that a human must judge, and requires an explicit human-run status.  Automated
mapping and sampling-rate results may accompany a manifest but never mark the
human pass complete.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "flight_tuning_manifest_v1"
DIMENSIONS = {"input", "camera", "landing"}
HUMAN_STATUSES = {"NOT_RUN", "IN_PROGRESS", "COMPLETE"}
TUNING_STATUSES = {"IN_PROGRESS", "BLOCKED", "AWAITING_HUMAN_REVIEW"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_number(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and value > 0


def _score(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and 1 <= value <= 5


def validate_manifest(data: Any) -> list[str]:
    """Return structural errors; an empty list means evidence is coherent."""
    if not isinstance(data, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if data.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if data.get("tuning_status") not in TUNING_STATUSES:
        errors.append("tuning_status must remain IN_PROGRESS, BLOCKED, or AWAITING_HUMAN_REVIEW")

    package = data.get("packaged_candidate")
    if not isinstance(package, dict):
        errors.append("packaged_candidate must be an object")
    else:
        for key in ("candidate_id", "artifact", "source_revision"):
            if not _text(package.get(key)):
                errors.append(f"packaged_candidate.{key} is required")

    human = data.get("human_playtest")
    if not isinstance(human, dict):
        errors.append("human_playtest must be an object")
    else:
        status = human.get("status")
        participants = human.get("participants")
        evidence = human.get("evidence")
        if status not in HUMAN_STATUSES:
            errors.append("human_playtest.status must be NOT_RUN, IN_PROGRESS, or COMPLETE")
        if not isinstance(participants, int) or isinstance(participants, bool) or participants < 0:
            errors.append("human_playtest.participants must be a non-negative integer")
        if status == "NOT_RUN":
            if participants != 0:
                errors.append("human_playtest.participants must be 0 when status is NOT_RUN")
            if evidence is not None:
                errors.append("human_playtest.evidence must be null when status is NOT_RUN")
        elif not _text(evidence):
            errors.append("human_playtest.evidence is required when a human run started")
        if status == "COMPLETE" and isinstance(participants, int) and participants < 1:
            errors.append("human_playtest.participants must be positive when status is COMPLETE")

    trials = data.get("trials")
    if not isinstance(trials, list) or not trials:
        return errors + ["trials must be a non-empty list"]
    seen: set[str] = set()
    dimensions: set[str] = set()
    for index, trial in enumerate(trials):
        label = f"trials[{index}]"
        if not isinstance(trial, dict):
            errors.append(f"{label} must be an object")
            continue
        trial_id = trial.get("id")
        if not _text(trial_id) or trial_id in seen:
            errors.append(f"{label}.id must be a unique non-empty string")
        else:
            seen.add(trial_id)
        dimension = trial.get("dimension")
        if dimension not in DIMENSIONS:
            errors.append(f"{label}.dimension must be input, camera, or landing")
        else:
            dimensions.add(dimension)
        if not _text(trial.get("scenario")):
            errors.append(f"{label}.scenario is required")
        if not _positive_number(trial.get("sampling_rate_hz")):
            errors.append(f"{label}.sampling_rate_hz must be positive")
        samples = trial.get("samples")
        if not isinstance(samples, int) or isinstance(samples, bool) or samples < 1:
            errors.append(f"{label}.samples must be a positive integer")
        metrics = trial.get("metrics")
        if not isinstance(metrics, dict):
            errors.append(f"{label}.metrics must be an object")
        else:
            for metric in ("comfort_score", "clarity_score", "landing_score"):
                if metric in metrics and not _score(metrics[metric]):
                    errors.append(f"{label}.metrics.{metric} must be an integer from 1 to 5")
            if not any(key in metrics for key in ("comfort_score", "clarity_score", "landing_score")):
                errors.append(f"{label}.metrics must include a 1-to-5 score")
        evidence = trial.get("evidence")
        if not isinstance(evidence, list) or not evidence or any(not _text(item) for item in evidence):
            errors.append(f"{label}.evidence must contain at least one reference")
    missing = sorted(DIMENSIONS - dimensions)
    if missing:
        errors.append(f"trials missing dimensions: {', '.join(missing)}")
    return errors


def validate(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    return validate_manifest(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest)
    if errors:
        for error in errors:
            print(f"FLIGHT_TUNING_MANIFEST_INVALID: {error}")
        return 1
    print(f"FLIGHT_TUNING_MANIFEST_VALID: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
