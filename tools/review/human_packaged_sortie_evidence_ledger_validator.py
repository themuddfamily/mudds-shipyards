#!/usr/bin/env python3
"""Validate the human packaged-sortie evidence handoff.

The ledger declares the exact Gate C/D scenarios and records where human
evidence will go. It intentionally keeps the human gate open: this tool cannot
turn a pending checklist into a playtest pass, cannot run a package, and cannot
substitute automated suites for first-time player observation.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from statistics import median
from typing import Any

SCHEMA = "human_packaged_sortie_evidence_ledger_v1"
OPEN_GATE_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
FORBIDDEN_CLAIMS = {"pass", "passed", "complete", "completed", "approved", "signed_off", "released"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SCENARIO_STEPS = {
    "guided": (
        "cold_boot", "begin", "walk_board_torrent", "same_tick_thrust",
        "physical_launch", "targets_defender", "lease_landing",
        "neutral_automatic_shutdown", "disembark", "completion",
    ),
    "sandbox": (
        "station_central", "station_aft", "station_habitat", "station_freight",
        "station_fleet_dock", "launch_land_exit_arrow", "launch_land_exit_jovian",
        "launch_land_exit_zenith", "launch_land_exit_halyard", "deliberate_crash",
        "recover_on_foot", "regenerate_reuse_craft",
    ),
    "settings_reentry": (
        "save_settings", "restart", "pause_resume", "camera_modes",
        "keyboard_mouse_lifecycle", "gamepad_lifecycle",
    ),
}
SCENARIO_REQUIRED_PASSES = {"guided": 3, "sandbox": 1, "settings_reentry": 1}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _finite_score(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and 1 <= value <= 5


def _forbidden_claim(value: Any) -> bool:
    return isinstance(value, str) and value.strip().lower().replace(" ", "_") in FORBIDDEN_CLAIMS


def _references(value: Any, prefix: str, errors: list[str], *, allow_none: bool) -> None:
    if value is None and allow_none:
        return
    if not isinstance(value, list) or not value:
        errors.append(f"{prefix} must be null before a run or a non-empty evidence list")
        return
    seen: set[tuple[str, str]] = set()
    for index, reference in enumerate(value):
        label = f"{prefix}[{index}]"
        if not isinstance(reference, dict):
            errors.append(f"{label} must be an object")
            continue
        if not isinstance(reference.get("kind"), str) or reference.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{label}.kind must be log, video, image, or report")
        if not _text(reference.get("path")):
            errors.append(f"{label}.path must be non-empty text")
        if not _sha(reference.get("sha256")):
            errors.append(f"{label}.sha256 must be a lowercase digest")
        path_value = reference.get("path")
        digest_value = reference.get("sha256")
        if isinstance(path_value, str) and isinstance(digest_value, str):
            identity = (path_value, digest_value)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier evidence reference")
            seen.add(identity)


def _validate_scenario(name: str, value: Any) -> list[str]:
    prefix = f"scenarios.{name}"
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{prefix} must be an object"]
    if not isinstance(value.get("status"), str) or value.get("status") not in OPEN_GATE_STATUSES:
        errors.append(f"{prefix}.status must remain open/pending")
    if _forbidden_claim(value.get("status")):
        errors.append(f"{prefix}.status cannot claim a human pass")
    required = SCENARIO_REQUIRED_PASSES[name]
    if value.get("required_passes") != required:
        errors.append(f"{prefix}.required_passes must be {required}")
    for key in ("observed_attempts", "passed_attempts"):
        if not _nonnegative_int(value.get(key)):
            errors.append(f"{prefix}.{key} must be a non-negative integer")
    if isinstance(value.get("passed_attempts"), int) and isinstance(value.get("observed_attempts"), int) and value["passed_attempts"] > value["observed_attempts"]:
        errors.append(f"{prefix}.passed_attempts cannot exceed observed_attempts")
    if value.get("fresh_process_required") is not True:
        errors.append(f"{prefix}.fresh_process_required must be true")
    steps = value.get("steps")
    expected_steps = list(SCENARIO_STEPS[name])
    if steps != expected_steps:
        errors.append(f"{prefix}.steps must exactly match the Gate C scenario contract")
    if not _text(value.get("notes")):
        errors.append(f"{prefix}.notes must be non-empty text")
    attempts = value.get("attempts")
    if not isinstance(attempts, list):
        errors.append(f"{prefix}.attempts must be an array")
        attempts = []
    ids: list[str] = []
    passed_count = 0
    for index, attempt in enumerate(attempts):
        label = f"{prefix}.attempts[{index}]"
        if not isinstance(attempt, dict):
            errors.append(f"{label} must be an object")
            continue
        attempt_id = attempt.get("id")
        if not _text(attempt_id):
            errors.append(f"{label}.id must be non-empty text")
        else:
            ids.append(attempt_id)
        if attempt.get("fresh_process") is not True:
            errors.append(f"{label}.fresh_process must be true")
        result = attempt.get("result")
        if not isinstance(result, str) or result not in {"pending", "observed", "failed"}:
            errors.append(f"{label}.result must be pending, observed, or failed")
        if result == "observed":
            passed_count += 1
        _references(attempt.get("evidence"), f"{label}.evidence", errors, allow_none=result == "pending")
    if len(ids) != len(set(ids)):
        errors.append(f"{prefix}.attempts.id values must be unique")
    if isinstance(value.get("observed_attempts"), int) and value["observed_attempts"] != len(attempts):
        errors.append(f"{prefix}.observed_attempts must equal attempts length")
    if isinstance(value.get("passed_attempts"), int) and value["passed_attempts"] != passed_count:
        errors.append(f"{prefix}.passed_attempts must equal observed attempt results")
    if value.get("status") == "not_performed" and attempts:
        errors.append(f"{prefix}.not_performed cannot contain attempts")
    return errors


def _validate_external_tuning(value: Any) -> list[str]:
    prefix = "external_tuning"
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{prefix} must be an object"]
    if not isinstance(value.get("status"), str) or value.get("status") not in OPEN_GATE_STATUSES:
        errors.append(f"{prefix}.status must remain open/pending")
    for key, expected in (("required_players", 5), ("required_completion_count", 4), ("time_limit_seconds", 1800)):
        if value.get(key) != expected:
            errors.append(f"{prefix}.{key} must be {expected}")
    if value.get("developer_intervention_allowed") is not False:
        errors.append(f"{prefix}.developer_intervention_allowed must be false")
    players = value.get("players")
    if not isinstance(players, list):
        errors.append(f"{prefix}.players must be an array")
        players = []
    if len(players) > 5:
        errors.append(f"{prefix}.players cannot exceed five first-time players")
    ids: list[str] = []
    completed = 0
    scores: dict[str, list[float]] = {"camera_comfort": [], "control_clarity": [], "landing_clarity": []}
    for index, player in enumerate(players):
        label = f"{prefix}.players[{index}]"
        if not isinstance(player, dict):
            errors.append(f"{label} must be an object")
            continue
        if not _text(player.get("id")):
            errors.append(f"{label}.id must be non-empty text")
        else:
            ids.append(player["id"])
        if player.get("first_time") is not True:
            errors.append(f"{label}.first_time must be true")
        if player.get("developer_intervention") is not False:
            errors.append(f"{label}.developer_intervention must be false")
        duration = player.get("duration_seconds")
        if not isinstance(duration, (int, float)) or isinstance(duration, bool) or duration < 0 or duration > 1800:
            errors.append(f"{label}.duration_seconds must be within 0..1800")
        outcomes = player.get("outcomes")
        if not isinstance(outcomes, dict):
            errors.append(f"{label}.outcomes must be an object")
        else:
            if all(outcomes.get(key) is True for key in ("launch", "fight", "redock", "disembark")):
                completed += 1
        for key in scores:
            score = player.get(key)
            if not _finite_score(score):
                errors.append(f"{label}.{key} must be a score from 1 to 5")
            else:
                scores[key].append(float(score))
        if not _nonnegative_int(player.get("p0_p1_findings")):
            errors.append(f"{label}.p0_p1_findings must be non-negative")
    if len(ids) != len(set(ids)):
        errors.append(f"{prefix}.players.id values must be unique")
    if isinstance(value.get("status"), str) and value.get("status") in {"observed", "failed"} and len(players) != 5:
        errors.append(f"{prefix}.{value.get('status')} evidence requires all five players")
    if value.get("status") == "observed":
        if completed < 4:
            errors.append(f"{prefix} requires at least four complete launch/fight/redock/disembark outcomes")
        for key, values in scores.items():
            if len(values) == 5 and median(values) < 4:
                errors.append(f"{prefix}.{key} median must be at least 4")
        if any(player.get("p0_p1_findings", 0) for player in players if isinstance(player, dict)):
            errors.append(f"{prefix}.observed cannot contain P0/P1 findings")
    _references(value.get("evidence"), f"{prefix}.evidence", errors, allow_none=value.get("status") == "not_performed")
    return errors


def _validate_package(value: Any) -> list[str]:
    prefix = "package"
    errors: list[str] = []
    if not isinstance(value, dict):
        return [f"{prefix} must be an object"]
    if not isinstance(value.get("status"), str) or value.get("status") not in {"not_run", "pending"}:
        errors.append(f"{prefix}.status must remain not_run or pending")
    if value.get("platform") != "Windows":
        errors.append(f"{prefix}.platform must be Windows")
    for key in ("build_identity", "source_commit"):
        if not _text(value.get(key)):
            errors.append(f"{prefix}.{key} must be non-empty text")
    artifact = value.get("artifact_sha256")
    if artifact is not None and not _sha(artifact):
        errors.append(f"{prefix}.artifact_sha256 must be null or a lowercase digest")
    if value.get("status") == "not_run" and value.get("execution_evidence") is not None:
        errors.append(f"{prefix}.execution_evidence must be null before a package run")
    _references(value.get("execution_evidence"), f"{prefix}.execution_evidence", errors, allow_none=value.get("status") == "not_run")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the human handoff is well formed."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if not isinstance(value.get("human_gate_status"), str) or value.get("human_gate_status") not in {"pending", "not_performed"}:
        errors.append("human_gate_status must remain pending or not_performed")
    for key in ("source_revision", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    if value.get("no_shortcuts") is not True:
        errors.append("no_shortcuts must be true")
    package = _validate_package(value.get("package"))
    errors.extend(package)
    scenarios = value.get("scenarios")
    if not isinstance(scenarios, dict):
        errors.append("scenarios must be an object")
    else:
        if set(scenarios) != set(SCENARIO_STEPS):
            errors.append("scenarios must exactly cover guided, sandbox, and settings_reentry")
        for name in SCENARIO_STEPS:
            if name in scenarios:
                errors.extend(_validate_scenario(name, scenarios[name]))
    errors.extend(_validate_external_tuning(value.get("external_tuning")))
    # Keep the claim boundary explicit even if future fields add decisions.
    for key in ("decision", "outcome", "sign_off"):
        if _forbidden_claim(value.get(key)):
            errors.append(f"{key} cannot claim human approval")
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"ledger unreadable: {exc}"]
    return validate_ledger(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.ledger)
    if errors:
        print("HUMAN_PACKAGED_SORTIE_LEDGER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("HUMAN_PACKAGED_SORTIE_LEDGER_READY: human gate remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
