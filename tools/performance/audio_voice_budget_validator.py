#!/usr/bin/env python3
"""Validate renderer-independent audio voice and source-memory budgets.

The input is a report emitted by ``audio_voice_census.gd``.  This gate covers
the deterministic scene/resource half of the audio budget only: player nodes,
exposed polyphony, unique retained streams, and decoded source payload bytes.
It deliberately does not infer native mixer voices, backend memory, CPU,
latency, clipping, balance, or audibility from a Dummy-audio census.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
SCENARIOS = {"station_resident", "cinder_loaded"}
METRICS = (
    "player_nodes",
    "summed_max_polyphony_ceiling",
    "retained_unique_streams",
    "retained_payload_bytes",
)
_SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _non_negative_integer(value: Any) -> bool:
    return _integer(value) and value >= 0


def validate_report(report: Any, label: str = "report") -> list[str]:
    """Return structural errors for one audio census report."""
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if report.get("scenario") not in SCENARIOS:
        errors.append(f"{label}.scenario must be one of {sorted(SCENARIOS)}")
    if report.get("loaded_instance_count") not in (0, 1):
        errors.append(f"{label}.loaded_instance_count must be 0 or 1")
    if not _non_negative_integer(report.get("settle_frames")) or report.get("settle_frames") < 1:
        errors.append(f"{label}.settle_frames must be a positive integer")
    if report.get("measurement_scope") != "scene_graph_audio_players_and_reachable_AudioStream_payloads":
        errors.append(f"{label}.measurement_scope is not the audio census scope")
    fingerprint = report.get("measurement_fingerprint")
    if not isinstance(fingerprint, str) or not _SHA256.fullmatch(fingerprint):
        errors.append(f"{label}.measurement_fingerprint must be a lowercase SHA-256")

    totals = report.get("totals")
    if not isinstance(totals, dict):
        errors.append(f"{label}.totals must be an object")
    else:
        for metric in ("player_nodes", "summed_max_polyphony_ceiling"):
            if not _non_negative_integer(totals.get(metric)):
                errors.append(f"{label}.totals.{metric} must be a non-negative integer")
        players = report.get("players")
        if isinstance(players, list) and _non_negative_integer(totals.get("player_nodes")):
            if totals["player_nodes"] != len(players):
                errors.append(f"{label}.totals.player_nodes does not match players length")

    streams = report.get("retained_streams")
    if not isinstance(streams, dict):
        errors.append(f"{label}.retained_streams must be an object")
    else:
        for metric in ("unique_count", "payload_bytes", "unknown_payload_count"):
            if not _non_negative_integer(streams.get(metric)):
                errors.append(f"{label}.retained_streams.{metric} must be a non-negative integer")
        rows = streams.get("rows")
        if isinstance(rows, list) and _non_negative_integer(streams.get("unique_count")):
            if streams["unique_count"] != len(rows):
                errors.append(f"{label}.retained_streams.unique_count does not match rows length")

    exclusions = report.get("authority_exclusions")
    if not isinstance(exclusions, list) or len(exclusions) != len(set(exclusions)):
        errors.append(f"{label}.authority_exclusions must be a unique array")
    else:
        required_exclusions = {
            "native_mixer_voice_count",
            "native_mixer_memory",
            "audio_thread_cpu_time",
            "process_ram",
            "frame_time",
        }
        missing = sorted(required_exclusions - set(exclusions))
        if missing:
            errors.append(f"{label}.authority_exclusions missing {', '.join(missing)}")
    return errors


def _budget_object(target: Any) -> dict[str, Any] | None:
    if not isinstance(target, dict):
        return None
    # Accept a target profile's explicit audio section, or a direct budget
    # object for simple CI invocation.
    audio = target.get("audio_budgets", target.get("audio"))
    return audio if isinstance(audio, dict) else target


def validate_budget(report: Any, target: Any) -> list[str]:
    """Return blocking errors when a census exceeds declared audio ceilings."""
    errors = validate_report(report)
    budgets = _budget_object(target)
    if budgets is None:
        return errors + ["audio budgets must be an object"]
    report_dict = report if isinstance(report, dict) else {}
    totals = report_dict.get("totals", {}) if isinstance(report_dict.get("totals"), dict) else {}
    streams = report_dict.get("retained_streams", {}) if isinstance(report_dict.get("retained_streams"), dict) else {}
    actual = {
        "player_nodes": totals.get("player_nodes"),
        "summed_max_polyphony_ceiling": totals.get("summed_max_polyphony_ceiling"),
        "retained_unique_streams": streams.get("unique_count"),
        "retained_payload_bytes": streams.get("payload_bytes"),
    }
    for metric in METRICS:
        ceiling = budgets.get(metric)
        if not _non_negative_integer(ceiling):
            errors.append(f"audio budget {metric} must be a non-negative integer")
        elif _non_negative_integer(actual[metric]) and actual[metric] > ceiling:
            errors.append(f"audio {metric} exceeds budget ({actual[metric]} > {ceiling})")

    per_bus = budgets.get("per_bus")
    if per_bus is not None:
        if not isinstance(per_bus, dict):
            errors.append("audio budget per_bus must be an object")
        else:
            bus_split = report_dict.get("bus_split")
            if not isinstance(bus_split, dict):
                errors.append("report.bus_split must be an object for per_bus budgets")
            else:
                for bus, ceiling in per_bus.items():
                    row = bus_split.get(bus)
                    if row is None:
                        errors.append(f"audio budget per_bus names absent bus {bus}")
                    elif not _non_negative_integer(ceiling):
                        errors.append(f"audio budget per_bus.{bus} must be a non-negative integer")
                    elif not isinstance(row, dict) or not _non_negative_integer(row.get("summed_max_polyphony_ceiling")):
                        errors.append(f"report.bus_split.{bus}.summed_max_polyphony_ceiling is invalid")
                    elif row["summed_max_polyphony_ceiling"] > ceiling:
                        errors.append(
                            f"audio bus {bus} polyphony exceeds budget "
                            f"({row['summed_max_polyphony_ceiling']} > {ceiling})"
                        )
    return errors


# Descriptive alias for callers that prefer one entry point.
validate_census = validate_budget


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", type=Path)
    parser.add_argument("--budgets", required=True, type=Path)
    args = parser.parse_args()
    report = json.loads(args.report.read_text(encoding="utf-8"))
    budgets = json.loads(args.budgets.read_text(encoding="utf-8"))
    errors = validate_budget(report, budgets)
    if errors:
        print("AUDIO_VOICE_BUDGET_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("AUDIO_VOICE_BUDGET_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
