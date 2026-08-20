#!/usr/bin/env python3
"""Validate runtime input-remapping and conflict-resolution evidence.

This validator checks detached evidence produced around the revisioned runtime
remap contract. It does not read or mutate Godot's ``InputMap`` and does not
claim that a physical keyboard, controller, or display was tested. The
manifest records both intentional authored overlaps and the atomic result of
reject/replace/stale/invalid remap trials.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "runtime_input_remap_evidence_v1"
CONFLICT_POLICIES = {"reject", "replace"}
OUTCOMES = {
    "rejected_conflict",
    "committed_replace",
    "committed_no_conflict",
    "rejected_invalid",
    "rejected_stale_revision",
}
HARDWARE_STATUSES = {"not_run", "planned", "blocked"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _required_text(mapping: dict[str, Any], key: str, prefix: str, errors: list[str]) -> str | None:
    value = mapping.get(key)
    if not _text(value):
        errors.append(f"{prefix}.{key} must be non-empty text")
        return None
    return value


def _string_list(value: Any, path: str, errors: list[str], *, nonempty: bool = True) -> list[str]:
    if not isinstance(value, list) or any(not _text(item) for item in value):
        errors.append(f"{path} must be a list of non-empty strings")
        return []
    if nonempty and not value:
        errors.append(f"{path} must not be empty")
    if len(value) != len(set(value)):
        errors.append(f"{path} must not contain duplicates")
    return value


def _validate_overlap(
    overlap: Any,
    index: int,
    action_set: set[str],
    seen_signatures: set[str],
) -> list[str]:
    prefix = f"authored_overlaps[{index}]"
    if not isinstance(overlap, dict):
        return [f"{prefix} must be an object"]
    errors: list[str] = []
    signature = _required_text(overlap, "binding_signature", prefix, errors)
    if signature is not None:
        if signature in seen_signatures:
            errors.append(f"{prefix}.binding_signature duplicates an earlier overlap")
        seen_signatures.add(signature)
    actions = _string_list(overlap.get("actions"), f"{prefix}.actions", errors)
    if len(actions) < 2:
        errors.append(f"{prefix}.actions must name at least two actions")
    unknown = sorted(set(actions) - action_set)
    if unknown:
        errors.append(f"{prefix}.actions contains unknown actions: {', '.join(unknown)}")
    if _required_text(overlap, "rationale", prefix, errors) is None:
        pass
    return errors


def _validate_conflict(
    conflict: Any,
    index: int,
    trial_prefix: str,
    target_action: str,
    candidate_signature: str,
    action_set: set[str],
    seen_pairs: set[tuple[str, str]],
) -> list[str]:
    prefix = f"{trial_prefix}.conflicts[{index}]"
    if not isinstance(conflict, dict):
        return [f"{prefix} must be an object"]
    errors: list[str] = []
    action = _required_text(conflict, "action", prefix, errors)
    signature = _required_text(conflict, "binding_signature", prefix, errors)
    if action is not None:
        if action not in action_set:
            errors.append(f"{prefix}.action is outside the action roster")
        if action == target_action:
            errors.append(f"{prefix}.action cannot equal the target action")
    if signature is not None and signature != candidate_signature:
        errors.append(f"{prefix}.binding_signature must match candidate_signature")
    if action is not None and signature is not None:
        pair = (action, signature)
        if pair in seen_pairs:
            errors.append(f"{prefix} duplicates an earlier conflict")
        seen_pairs.add(pair)
    return errors


def _validate_trial(trial: Any, index: int, action_set: set[str]) -> list[str]:
    prefix = f"trials[{index}]"
    if not isinstance(trial, dict):
        return [f"{prefix} must be an object"]
    errors: list[str] = []
    trial_id = _required_text(trial, "id", prefix, errors)
    action = _required_text(trial, "action", prefix, errors)
    candidate = _required_text(trial, "candidate_signature", prefix, errors)
    resolution = _required_text(trial, "resolution", prefix, errors)
    outcome = _required_text(trial, "outcome", prefix, errors)
    for key in ("expected_revision", "revision_before", "revision_after"):
        if not _integer(trial.get(key)):
            errors.append(f"{prefix}.{key} must be a non-negative integer")
    if action is not None and action not in action_set:
        errors.append(f"{prefix}.action is outside the action roster")
    if resolution not in CONFLICT_POLICIES:
        errors.append(f"{prefix}.resolution must be reject or replace")
    if outcome not in OUTCOMES:
        errors.append(f"{prefix}.outcome is unsupported")
    conflicts = trial.get("conflicts")
    if not isinstance(conflicts, list):
        errors.append(f"{prefix}.conflicts must be an array")
        conflicts = []
    seen_pairs: set[tuple[str, str]] = set()
    for conflict_index, conflict in enumerate(conflicts):
        errors.extend(_validate_conflict(
            conflict,
            conflict_index,
            prefix,
            action or "",
            candidate or "",
            action_set,
            seen_pairs,
        ))
    before = trial.get("revision_before")
    after = trial.get("revision_after")
    expected = trial.get("expected_revision")
    unchanged = trial.get("profile_unchanged")
    if not isinstance(unchanged, bool):
        errors.append(f"{prefix}.profile_unchanged must be boolean")
    fingerprint_before = _required_text(trial, "profile_fingerprint_before", prefix, errors)
    fingerprint_after = _required_text(trial, "profile_fingerprint_after", prefix, errors)
    if isinstance(unchanged, bool) and fingerprint_before is not None and fingerprint_after is not None:
        if unchanged != (fingerprint_before == fingerprint_after):
            errors.append(f"{prefix}.profile_unchanged disagrees with profile fingerprints")
    if _required_text(trial, "notes", prefix, errors) is None:
        pass

    if outcome == "rejected_conflict":
        if resolution != "reject":
            errors.append(f"{prefix}.rejected_conflict must use reject resolution")
        if not conflicts:
            errors.append(f"{prefix}.rejected_conflict must include conflicts")
        if before != after or unchanged is not True:
            errors.append(f"{prefix}.rejected_conflict must leave revision/profile unchanged")
    elif outcome == "committed_replace":
        if resolution != "replace":
            errors.append(f"{prefix}.committed_replace must use replace resolution")
        if not conflicts:
            errors.append(f"{prefix}.committed_replace must include conflicts")
        if isinstance(before, int) and after != before + 1:
            errors.append(f"{prefix}.committed_replace must advance revision exactly once")
        if unchanged is not False:
            errors.append(f"{prefix}.committed_replace must change the profile")
    elif outcome == "committed_no_conflict":
        if conflicts:
            errors.append(f"{prefix}.committed_no_conflict cannot include conflicts")
        if isinstance(before, int) and after != before + 1:
            errors.append(f"{prefix}.committed_no_conflict must advance revision exactly once")
        if unchanged is not False:
            errors.append(f"{prefix}.committed_no_conflict must change the profile")
    elif outcome == "rejected_invalid":
        if conflicts:
            errors.append(f"{prefix}.rejected_invalid cannot include conflicts")
        if before != after or unchanged is not True:
            errors.append(f"{prefix}.rejected_invalid must leave revision/profile unchanged")
    elif outcome == "rejected_stale_revision":
        if expected == before:
            errors.append(f"{prefix}.rejected_stale_revision must use a stale expected revision")
        if conflicts:
            errors.append(f"{prefix}.rejected_stale_revision cannot include conflicts")
        if before != after or unchanged is not True:
            errors.append(f"{prefix}.rejected_stale_revision must leave revision/profile unchanged")
    if outcome != "rejected_stale_revision" and expected != before:
        errors.append(f"{prefix}.expected_revision must match revision_before")
    return errors


def validate_manifest(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the evidence is coherent."""
    if not isinstance(value, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("source_revision", "contract", "evidence_scope"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    if value.get("runtime_authority_unchanged") is not True:
        errors.append("runtime_authority_unchanged must remain true")
    if value.get("hardware_validation_status") not in HARDWARE_STATUSES:
        errors.append("hardware_validation_status must remain not_run, planned, or blocked")
    policies = _string_list(value.get("conflict_policies"), "conflict_policies", errors)
    if set(policies) != CONFLICT_POLICIES:
        errors.append("conflict_policies must exactly cover reject and replace")

    roster = value.get("action_roster")
    if not isinstance(roster, dict):
        errors.append("action_roster must be an object")
        action_set: set[str] = set()
    else:
        required = _string_list(roster.get("required_actions"), "action_roster.required_actions", errors)
        covered = _string_list(roster.get("covered_actions"), "action_roster.covered_actions", errors)
        if required != covered:
            errors.append("action_roster.covered_actions must preserve required_actions order")
        action_set = set(required)

    overlaps = value.get("authored_overlaps")
    if not isinstance(overlaps, list) or not overlaps:
        errors.append("authored_overlaps must contain at least one intentional overlap")
    else:
        seen_signatures: set[str] = set()
        for index, overlap in enumerate(overlaps):
            errors.extend(_validate_overlap(overlap, index, action_set, seen_signatures))

    trials = value.get("trials")
    if not isinstance(trials, list) or not trials:
        errors.append("trials must contain at least one remap trial")
    else:
        trial_ids: list[str] = []
        for index, trial in enumerate(trials):
            if isinstance(trial, dict) and _text(trial.get("id")):
                trial_ids.append(trial["id"])
            errors.extend(_validate_trial(trial, index, action_set))
        if len(trial_ids) != len(set(trial_ids)):
            errors.append("trials.id values must be unique")
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    return validate_manifest(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest)
    if errors:
        print("RUNTIME_INPUT_REMAP_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("RUNTIME_INPUT_REMAP_EVIDENCE_READY: hardware validation remains external")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
