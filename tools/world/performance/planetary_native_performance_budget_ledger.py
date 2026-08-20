#!/usr/bin/env python3
"""Validate a native-performance budget ledger for the authored planet.

The ledger records targets for minimum and target profiles while keeping the
native measurement gate explicitly NOT_RUN.  It does not launch a package,
measure the host, fabricate metrics, or grant performance/runtime authority.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_native_performance_budget"
EVIDENCE_MODE = "budget_ledger_native_not_run"
REQUIRED_PROFILES = ("minimum", "target")
REQUIRED_SCENARIOS = (
    "orbit_to_surface",
    "settlement_route",
    "save_reentry",
    "long_session_orbit_surface",
)
METRIC_BUDGETS = {
    "frame_time_ms": (0.1, 1000.0),
    "vram_mb": (1.0, 262144.0),
    "resident_tiles": (1.0, 100000.0),
    "physics_bodies": (1.0, 1000000.0),
    "audio_voices": (1.0, 1024.0),
    "startup_seconds": (0.1, 3600.0),
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _finite_positive(value: Any, minimum: float, maximum: float) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value)) and minimum <= float(value) <= maximum


def _not_run(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    if value.get("status") != "NOT_RUN":
        errors.append(f"{label}.status must be NOT_RUN")
    if value.get("native_executed") is not False:
        errors.append(f"{label}.native_executed must be false")
    if value.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null while native is NOT_RUN")
    if not _text(value.get("reason")):
        errors.append(f"{label}.reason is required while native is NOT_RUN")


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    """Return blocking errors for a budget-only native ledger."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("native_claims", "fabricated_metrics", "runtime_authority", "package_launched"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    if value.get("platform") not in {"windows-x86_64", "windows-arm64"}:
        errors.append(f"{label}.platform must be a Windows platform")
    if value.get("world_id") != "ember_moon":
        errors.append(f"{label}.world_id must be ember_moon")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision is required")
    _not_run(value.get("native_playtest"), f"{label}.native_playtest", errors)

    profiles = value.get("profiles")
    if not isinstance(profiles, list):
        errors.append(f"{label}.profiles must be an array")
        profiles = []
    profile_ids: list[str] = []
    for index, profile in enumerate(profiles):
        prefix = f"{label}.profiles[{index}]"
        if not isinstance(profile, dict):
            errors.append(f"{prefix} must be an object")
            continue
        profile_id = profile.get("id")
        if not _text(profile_id):
            errors.append(f"{prefix}.id is required")
        elif profile_id in profile_ids:
            errors.append(f"{prefix}.id must be unique")
        profile_ids.append(profile_id)
        _not_run(profile, prefix, errors)
        budgets = profile.get("budget")
        if not isinstance(budgets, dict):
            errors.append(f"{prefix}.budget must be an object")
            budgets = {}
        for metric, (minimum, maximum) in METRIC_BUDGETS.items():
            if not _finite_positive(budgets.get(metric), minimum, maximum):
                errors.append(f"{prefix}.budget.{metric} must be a bounded positive number")
        observations = profile.get("observations")
        if not isinstance(observations, dict):
            errors.append(f"{prefix}.observations must be an object")
        else:
            for metric in METRIC_BUDGETS:
                if observations.get(metric) is not None:
                    errors.append(f"{prefix}.observations.{metric} must remain null while native is NOT_RUN")
    if tuple(profile_ids) != REQUIRED_PROFILES:
        errors.append(f"{label}.profiles must contain minimum and target in order")

    scenarios = value.get("scenarios")
    if not isinstance(scenarios, list):
        errors.append(f"{label}.scenarios must be an array")
        scenarios = []
    scenario_ids: list[str] = []
    for index, scenario in enumerate(scenarios):
        prefix = f"{label}.scenarios[{index}]"
        if not isinstance(scenario, dict):
            errors.append(f"{prefix} must be an object")
            continue
        scenario_id = scenario.get("id")
        if not _text(scenario_id):
            errors.append(f"{prefix}.id is required")
        elif scenario_id in scenario_ids:
            errors.append(f"{prefix}.id must be unique")
        scenario_ids.append(scenario_id)
        _not_run(scenario, prefix, errors)
    if tuple(scenario_ids) != REQUIRED_SCENARIOS:
        errors.append(f"{label}.scenarios must contain the required authored route scenarios in order")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("renderer", "physics", "streaming", "terrain", "movement", "audio", "save", "network", "gameplay"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    try:
        value = json.loads(args.ledger.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_NATIVE_PERFORMANCE_INVALID: {exc}")
        return 1
    errors = validate_ledger(value)
    if errors:
        print("PLANETARY_NATIVE_PERFORMANCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_NATIVE_PERFORMANCE_VALID: native measurement remains NOT_RUN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
