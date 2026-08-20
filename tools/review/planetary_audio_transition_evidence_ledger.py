#!/usr/bin/env python3
"""Validate authored planetary interior/exterior audio transition evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_audio_transition_evidence_v1"
STATES = ("exterior", "threshold", "interior")
OPEN = {"pending", "not_performed"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "region_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    profiles = value.get("profiles")
    if not isinstance(profiles, list) or len(profiles) < 2:
        errors.append(f"{label}.profiles must contain exterior and interior profiles")
        profiles = []
    profile_ids: set[str] = set()
    for index, profile in enumerate(profiles):
        prefix = f"{label}.profiles[{index}]"
        if not isinstance(profile, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = profile.get("id")
        if not _text(ident) or ident in profile_ids:
            errors.append(f"{prefix}.id must be unique")
        profile_ids.add(ident)
        if profile.get("state") not in {"exterior", "interior"}:
            errors.append(f"{prefix}.state must be exterior or interior")
        if not _text(profile.get("bus_id")) or not _text(profile.get("loop_asset")):
            errors.append(f"{prefix} requires bus_id and loop_asset")
        if not profile.get("asset_path", "").startswith("res://"):
            errors.append(f"{prefix}.asset_path must be a res:// path")
    transitions = value.get("transitions")
    if not isinstance(transitions, list) or len(transitions) != len(STATES):
        errors.append(f"{label}.transitions must contain exterior, threshold, and interior")
        transitions = transitions if isinstance(transitions, list) else []
    seen: set[str] = set()
    for index, transition in enumerate(transitions):
        prefix = f"{label}.transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = transition.get("state")
        if ident not in STATES or ident in seen:
            errors.append(f"{prefix}.state must be unique and ordered")
        seen.add(ident)
        if ident != STATES[index] if index < len(STATES) else True:
            errors.append(f"{prefix}.state is out of order")
        if not _text(transition.get("trigger")) or not _text(transition.get("fade_policy")):
            errors.append(f"{prefix} requires trigger and fade_policy")
        if transition.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    audition = value.get("hardware_audition")
    if not isinstance(audition, dict) or audition.get("status") != "NOT_RUN" or audition.get("evidence") is not None:
        errors.append(f"{label}.hardware_audition must remain NOT_RUN without evidence")
    exclusions = value.get("authority_exclusions")
    required = {"audio_playback", "mix_resolution", "hardware_audition"}
    if not isinstance(exclusions, list) or not required.issubset(set(exclusions)):
        errors.append(f"{label}.authority_exclusions must preserve audio and audition exclusions")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_AUDIO_TRANSITION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_AUDIO_TRANSITION_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
