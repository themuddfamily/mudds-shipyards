#!/usr/bin/env python3
"""Validate scenario/source-family audio voice ceilings without native mixer data."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_voice_ceiling_evidence_v1"
REQUIRED_SCENARIOS = {"station", "combat", "planetary_surface", "reentry"}
FAMILIES = {"music", "machinery", "combat", "surface", "ui"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_report(report: Any) -> list[str]:
    if not isinstance(report, dict):
        return ["report must be an object"]
    errors: list[str] = []
    if report.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "evidence_bundle", "measurement_scope"):
        if not _text(report.get(key)):
            errors.append(f"{key} is required")
    if report.get("measurement_scope") not in {"scene_graph", "dummy_audio"}:
        errors.append("measurement_scope must be scene_graph or dummy_audio")
    if report.get("native_mixer_status") != "OPEN":
        errors.append("native_mixer_status must be OPEN")
    if report.get("claim") != "AUTOMATED_CEILING_ONLY":
        errors.append("claim must be AUTOMATED_CEILING_ONLY")
    if not _text(report.get("boundary_note")):
        errors.append("boundary_note is required")

    scenarios = report.get("scenarios")
    if not isinstance(scenarios, list) or not scenarios:
        errors.append("scenarios must be a non-empty array")
        scenarios = []
    names: set[str] = set()
    for index, scenario in enumerate(scenarios):
        prefix = f"scenarios[{index}]"
        if not isinstance(scenario, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = scenario.get("name")
        if name not in REQUIRED_SCENARIOS:
            errors.append(f"{prefix}.name is invalid")
        elif name in names:
            errors.append(f"{prefix}.name is duplicated")
        else:
            names.add(name)
        if not _text(scenario.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        rows = scenario.get("families")
        if not isinstance(rows, list) or not rows:
            errors.append(f"{prefix}.families must be a non-empty array")
            rows = []
        family_names: set[str] = set()
        for family_index, row in enumerate(rows):
            row_prefix = f"{prefix}.families[{family_index}]"
            if not isinstance(row, dict):
                errors.append(f"{row_prefix} must be an object")
                continue
            family = row.get("name")
            if family not in FAMILIES:
                errors.append(f"{row_prefix}.name is invalid")
            elif family in family_names:
                errors.append(f"{row_prefix}.name is duplicated")
            else:
                family_names.add(family)
            for key in ("declared_ceiling", "observed_peak"):
                if not _integer(row.get(key)):
                    errors.append(f"{row_prefix}.{key} must be a non-negative integer")
            if _integer(row.get("declared_ceiling")) and _integer(row.get("observed_peak")) and row["observed_peak"] > row["declared_ceiling"]:
                errors.append(f"{row_prefix}.observed_peak exceeds declared_ceiling")
        missing_families = FAMILIES - family_names
        if missing_families:
            errors.append(f"{prefix}.families must cover: {', '.join(sorted(missing_families))}")
    missing_scenarios = REQUIRED_SCENARIOS - names
    if missing_scenarios:
        errors.append(f"scenarios must cover: {', '.join(sorted(missing_scenarios))}")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    args = parser.parse_args(argv)
    errors = validate_report(json.loads(args.report.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_VOICE_CEILING_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_VOICE_CEILING_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
