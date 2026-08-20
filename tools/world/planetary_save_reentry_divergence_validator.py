#!/usr/bin/env python3
"""Validate detached planetary save/re-entry divergence evidence.

The record joins the existing JSON-safe planetary save contract with a
generation-fenced re-entry witness.  It proves which state is retained and
which stale surface checkpoint is rejected, without writing a file, restoring
a scene, or claiming a packaged/native run.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "planetary_save_reentry_divergence"
EVIDENCE_MODE = "detached_contract_fixture"
REQUIRED_WORLD_ID = "ember_moon"
REQUIRED_PHASES = {"orbit", "surface"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _snapshot(value: Any, label: str, errors: list[str]) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
        return None
    for key in ("state", "world_id", "session_id", "phase", "payload_digest"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} must be non-empty text")
    if value.get("world_id") != REQUIRED_WORLD_ID:
        errors.append(f"{label}.world_id must be {REQUIRED_WORLD_ID}")
    if value.get("state") not in {"active", "detached"}:
        errors.append(f"{label}.state must be active or detached")
    if value.get("phase") not in REQUIRED_PHASES:
        errors.append(f"{label}.phase must be orbit or surface")
    for key in ("attachment_generation", "checkpoint_generation", "physics_tick", "frame_generation"):
        if not _nonnegative_int(value.get(key)):
            errors.append(f"{label}.{key} must be a non-negative integer")
    if value.get("local_streaming_position_persisted") is not False:
        errors.append(f"{label}.local_streaming_position_persisted must be false")
    return value


def validate_evidence(value: Any, label: str = "evidence") -> list[str]:
    """Return blocking save/re-entry divergence errors."""

    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if value.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if value.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    for key in ("native_claims", "filesystem_write", "scene_restore", "runtime_save_authority"):
        if value.get(key) is not False:
            errors.append(f"{label}.{key} must be false for detached evidence")
    if not _text(value.get("source_revision")):
        errors.append(f"{label}.source_revision must be non-empty text")

    initial = _snapshot(value.get("initial_snapshot"), f"{label}.initial_snapshot", errors)
    detached = _snapshot(value.get("detached_snapshot"), f"{label}.detached_snapshot", errors)
    reentered = _snapshot(value.get("reentered_snapshot"), f"{label}.reentered_snapshot", errors)
    if initial is not None and detached is not None:
        if initial.get("state") != "active":
            errors.append(f"{label}.initial_snapshot.state must be active")
        if detached.get("state") != "detached":
            errors.append(f"{label}.detached_snapshot.state must be detached")
        if detached.get("session_id") != initial.get("session_id"):
            errors.append(f"{label}.detached_snapshot must retain the session ID")
        if detached.get("attachment_generation") != initial.get("attachment_generation"):
            errors.append(f"{label}.detach must not advance attachment generation")
        if detached.get("checkpoint_generation") != initial.get("checkpoint_generation"):
            errors.append(f"{label}.detach must retain checkpoint generation")
        if detached.get("physics_tick") != initial.get("physics_tick"):
            errors.append(f"{label}.detach must not advance physics progress")
        if detached.get("payload_digest") != initial.get("payload_digest"):
            errors.append(f"{label}.detach must retain payload digest")
    if detached is not None and reentered is not None:
        if reentered.get("state") != "active":
            errors.append(f"{label}.reentered_snapshot.state must be active")
        if reentered.get("session_id") != detached.get("session_id"):
            errors.append(f"{label}.reentry must retain the session ID")
        if reentered.get("attachment_generation") != detached.get("attachment_generation", 0) + 1:
            errors.append(f"{label}.reentry attachment generation must advance exactly once")
        for key in ("checkpoint_generation", "physics_tick", "payload_digest"):
            if reentered.get(key) != detached.get(key):
                errors.append(f"{label}.reentry must retain {key}")

    orbit = value.get("orbit_restore")
    if not isinstance(orbit, dict):
        errors.append(f"{label}.orbit_restore must be an object")
    else:
        if orbit.get("accepted") is not True:
            errors.append(f"{label}.orbit_restore.accepted must be true")
        if orbit.get("absolute_coordinate_preserved") is not True:
            errors.append(f"{label}.orbit_restore.absolute_coordinate_preserved must be true")
        if not _positive_int(orbit.get("saved_frame_generation")) or not _positive_int(orbit.get("restore_frame_generation")):
            errors.append(f"{label}.orbit_restore frame generations must be positive")
        elif orbit["restore_frame_generation"] <= orbit["saved_frame_generation"]:
            errors.append(f"{label}.orbit_restore.restore_frame_generation must advance")
        if not _text(orbit.get("absolute_coordinate_digest")):
            errors.append(f"{label}.orbit_restore.absolute_coordinate_digest is required")

    surface = value.get("surface_restore")
    if not isinstance(surface, dict):
        errors.append(f"{label}.surface_restore must be an object")
    else:
        if surface.get("stale_attempt_accepted") is not False:
            errors.append(f"{label}.surface_restore.stale_attempt_accepted must be false")
        if surface.get("stale_rejection_reason") != "surface_checkpoint_generation_mismatch":
            errors.append(f"{label}.surface_restore must name the exact stale-generation rejection")
        if surface.get("recapture_accepted") is not True:
            errors.append(f"{label}.surface_restore.recapture_accepted must be true")
        if not _positive_int(surface.get("saved_frame_generation")) or not _positive_int(surface.get("recapture_frame_generation")):
            errors.append(f"{label}.surface_restore frame generations must be positive")
        elif surface["recapture_frame_generation"] <= surface["saved_frame_generation"]:
            errors.append(f"{label}.surface_restore.recapture_frame_generation must advance")

    guards = value.get("divergence_guards")
    if not isinstance(guards, dict):
        errors.append(f"{label}.divergence_guards must be an object")
    else:
        for key in (
            "stale_attachment_rejected",
            "stale_checkpoint_rejected",
            "duplicate_session_rejected",
            "payload_digest_unchanged",
            "local_position_not_persisted",
            "generation_fenced",
        ):
            if guards.get(key) is not True:
                errors.append(f"{label}.divergence_guards.{key} must be true")

    authority = value.get("authority")
    if not isinstance(authority, dict):
        errors.append(f"{label}.authority must be an object")
    else:
        for key in ("filesystem", "scene_restore", "physics", "streaming", "gameplay", "clock", "origin_shift", "network"):
            if authority.get(key) is not False:
                errors.append(f"{label}.authority.{key} must be false")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args(argv)
    try:
        report = json.loads(args.evidence.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"PLANETARY_SAVE_REENTRY_INVALID: {exc}")
        return 1
    errors = validate_evidence(report)
    if errors:
        print("PLANETARY_SAVE_REENTRY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_SAVE_REENTRY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
