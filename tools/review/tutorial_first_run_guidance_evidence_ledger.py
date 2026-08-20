#!/usr/bin/env python3
"""Validate the tutorial/first-run guidance evidence handoff.

The ledger freezes the ordered onboarding checkpoints and their controller,
keyboard, and accessible prompt variants.  It is a presentation contract,
not gameplay authority: detached validation cannot simulate a first-time
player or turn a source declaration into human playthrough evidence.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "tutorial_first_run_guidance_evidence_v1"
HUMAN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
STEP_STATUSES = {"planned", "pending", "observed", "issue"}
INPUT_FAMILIES = ("controller", "keyboard")
REQUIRED_STEPS = (
    "look", "move", "board", "thrust", "launch", "combat", "land", "disembark",
)
REQUIRED_CHECKPOINTS = tuple(f"{step}_seen" for step in REQUIRED_STEPS)
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _sha(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA.fullmatch(value))


def _references(value: Any, prefix: str, errors: list[str], *, allow_none: bool) -> None:
    if value is None and allow_none:
        return
    if not isinstance(value, list) or not value:
        errors.append(f"{prefix} must be null while pending or a non-empty evidence list")
        return
    seen: set[tuple[str, str]] = set()
    for index, reference in enumerate(value):
        label = f"{prefix}[{index}]"
        if not isinstance(reference, dict):
            errors.append(f"{label} must be an object")
            continue
        if reference.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{label}.kind must be log, video, image, or report")
        if not _text(reference.get("path")):
            errors.append(f"{label}.path must be non-empty text")
        if not _sha(reference.get("sha256")):
            errors.append(f"{label}.sha256 must be a lowercase digest")
        path, digest = reference.get("path"), reference.get("sha256")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier reference")
            seen.add(identity)


def _validate_steps(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["steps must contain exactly eight ordered first-run checkpoints"]
    if len(value) != len(REQUIRED_STEPS):
        errors.append("steps must contain exactly eight ordered first-run checkpoints")
    ids: list[str] = []
    checkpoints: list[str] = []
    evidence_seen: set[tuple[str, str]] = set()
    for index, step in enumerate(value):
        prefix = f"steps[{index}]"
        if not isinstance(step, dict):
            errors.append(f"{prefix} must be an object")
            continue
        step_id, checkpoint_id = step.get("id"), step.get("checkpoint_id")
        if not _text(step_id):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(step_id)
        if not _text(checkpoint_id):
            errors.append(f"{prefix}.checkpoint_id must be non-empty text")
        else:
            checkpoints.append(checkpoint_id)
        for key in ("title", "expected_outcome", "source"):
            if not _text(step.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        for family in INPUT_FAMILIES:
            if not _text(step.get(f"{family}_prompt")):
                errors.append(f"{prefix}.{family}_prompt must be non-empty text")
        if not _text(step.get("accessible_prompt")):
            errors.append(f"{prefix}.accessible_prompt must be non-empty text")
        status = step.get("status")
        if not isinstance(status, str) or status not in STEP_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        evidence = step.get("evidence")
        allow_none = isinstance(status, str) and status in {"planned", "pending"}
        _references(evidence, f"{prefix}.evidence", errors, allow_none=allow_none)
        if isinstance(evidence, list):
            for reference in evidence:
                if not isinstance(reference, dict):
                    continue
                path, digest = reference.get("path"), reference.get("sha256")
                if isinstance(path, str) and isinstance(digest, str) and _sha(digest):
                    identity = (path, digest)
                    if identity in evidence_seen:
                        errors.append(f"{prefix}.evidence duplicates an earlier ledger reference")
                    evidence_seen.add(identity)
    if len(ids) != len(set(ids)):
        errors.append("steps.id values must be unique")
    if len(checkpoints) != len(set(checkpoints)):
        errors.append("steps.checkpoint_id values must be unique")
    if tuple(ids) != REQUIRED_STEPS:
        errors.append("steps must exactly match the frozen first-run order")
    if tuple(checkpoints) != REQUIRED_CHECKPOINTS:
        errors.append("steps must exactly match the frozen checkpoint order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open human gate."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("human_playthrough_status") not in HUMAN_STATUSES:
        errors.append("human_playthrough_status must remain pending, not_performed, in_progress, or failed")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    if value.get("human_playthrough_performed") is not False:
        errors.append("human_playthrough_performed must remain false")
    if value.get("presentation_only") is not True:
        errors.append("presentation_only must be true")
    if value.get("reads_input_map") is not False:
        errors.append("reads_input_map must remain false")
    if value.get("gameplay_authority") is not False:
        errors.append("gameplay_authority must remain false")
    if value.get("save_authority") is not False:
        errors.append("save_authority must remain false")
    if value.get("developer_intervention_allowed") is not False:
        errors.append("developer_intervention_allowed must be false")
    if value.get("input_families") != list(INPUT_FAMILIES):
        errors.append("input_families must exactly match controller, keyboard")
    errors.extend(_validate_steps(value.get("steps")))
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
        print("TUTORIAL_FIRST_RUN_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("TUTORIAL_FIRST_RUN_READY: human first-run playthrough remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
