#!/usr/bin/env python3
"""Validate the open orbit-to-surface native and human gate ledger.

This records readiness evidence and keeps native execution and human review
explicitly open.  It does not execute a flight, render a scene, or approve a
planetary production gate.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
PHASES = ("orbit", "entry", "surface", "landing")
OPEN_STATUSES = {"NOT_RUN", "PENDING", "UNKNOWN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _gate(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return
    status = value.get("status")
    if status not in OPEN_STATUSES:
        errors.append(f"{label}.status must remain open")
    if status == "NOT_RUN" and value.get("evidence") is not None:
        errors.append(f"{label}.evidence must be null when NOT_RUN")
    if status in {"PENDING", "UNKNOWN"} and value.get("evidence") is not None and not _text(value.get("evidence")):
        errors.append(f"{label}.evidence must be non-empty when provided")
    if status == "NOT_RUN" and not _text(value.get("reason")):
        errors.append(f"{label}.reason is required when NOT_RUN")


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("world_id", "source_revision", "owner"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    phases = value.get("phases")
    if not isinstance(phases, list) or len(phases) != len(PHASES):
        errors.append(f"{label}.phases must contain orbit, entry, surface, and landing")
        phases = phases if isinstance(phases, list) else []
    seen: set[str] = set()
    for index, phase in enumerate(phases):
        prefix = f"{label}.phases[{index}]"
        if not isinstance(phase, dict):
            errors.append(f"{prefix} must be an object")
            continue
        phase_id = phase.get("id")
        if phase_id not in PHASES or phase_id in seen:
            errors.append(f"{prefix}.id must be a unique ordered phase")
        seen.add(phase_id)
        if phase_id != PHASES[index] if index < len(PHASES) else True:
            errors.append(f"{prefix}.id is out of order")
        _gate(phase.get("native_gate"), f"{prefix}.native_gate", errors)
        _gate(phase.get("human_gate"), f"{prefix}.human_gate", errors)
        if not _text(phase.get("acceptance_note")):
            errors.append(f"{prefix}.acceptance_note is required")
    for key in ("native_execution", "human_playtest"):
        _gate(value.get(key), f"{label}.{key}", errors)
    if value.get("overall_status") not in {"OPEN", "BLOCKED_BY_GATES"}:
        errors.append(f"{label}.overall_status must remain OPEN or BLOCKED_BY_GATES")
    exclusions = value.get("claims_excluded")
    required = {"native_hardware_pass", "human_visual_signoff", "complete_surface_flight"}
    if not isinstance(exclusions, list) or not required.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve native, human, and complete-flight exclusions")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_ORBIT_SURFACE_LEDGER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_ORBIT_SURFACE_LEDGER_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
