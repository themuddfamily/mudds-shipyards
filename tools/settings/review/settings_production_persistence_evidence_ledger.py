#!/usr/bin/env python3
"""Validate the production runtime-settings persistence evidence handoff.

The ledger freezes the persisted setting roster, transaction/re-entry cases,
and authority boundaries.  It does not access user data, simulate an OS
interruption, or claim that a detached contract test is production evidence.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "settings_production_persistence_evidence_v1"
OPEN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
CASE_STATUSES = {"planned", "pending", "observed", "issue"}
EVIDENCE_KINDS = {"log", "video", "image", "report"}
SHA = re.compile(r"^[0-9a-f]{40,64}$")
REQUIRED_SETTING_KEYS = (
    "ship_mouse_sensitivity", "on_foot_mouse_sensitivity", "invert_ship_y",
    "invert_on_foot_y", "camera_fov", "master_volume", "ambience_volume",
    "engine_volume", "weapons_volume", "ui_volume", "music_volume",
    "graphics_profile", "window_mode", "control_preset", "ui_scale",
    "colorblind_palette", "reduced_motion", "captions_enabled",
    "input_binding_profile",
)
REQUIRED_CASES = (
    "validated_startup", "empty_defaults", "corrupt_load", "newer_schema_load",
    "failed_load", "changed_setting_save", "no_op_no_save", "reset_defaults",
    "explicit_save", "failed_save", "signal_reentry", "namespace_preservation",
    "main_detach_reentry", "process_restart_monotonic_commit",
    "safe_start_recommendation_rollback",
)


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


def _validate_roster(value: Any) -> list[str]:
    if value != list(REQUIRED_SETTING_KEYS):
        return ["setting_keys must exactly match the frozen production setting roster"]
    return []


def _validate_authority(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, dict):
        return ["authority must be an object"]
    expected_bools = {
        "load_once": True,
        "load_before_first_apply": True,
        "reentry_reloads": False,
        "detached_report_only": True,
        "wall_clock_used": False,
        "automatic_repair": False,
        "delete_policy": False,
        "os_crash_hook": False,
        "nested_transaction_rejected": True,
        "unrelated_namespaces_preserved": True,
    }
    for key, expected in expected_bools.items():
        if value.get(key) is not expected:
            errors.append(f"authority.{key} must be {str(expected).lower()}")
    for key in ("store_count", "adapter_count"):
        if value.get(key) != 1:
            errors.append(f"authority.{key} must be 1")
    if value.get("identity_scope") not in {"process_lifetime", "injected_main_lifetime"}:
        errors.append("authority.identity_scope must be process_lifetime or injected_main_lifetime")
    return errors


def _validate_cases(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list):
        return ["cases must contain exactly fifteen persistence cases"]
    if len(value) != len(REQUIRED_CASES):
        errors.append("cases must contain exactly fifteen persistence cases")
    ids: list[str] = []
    evidence_seen: set[tuple[str, str]] = set()
    for index, case in enumerate(value):
        prefix = f"cases[{index}]"
        if not isinstance(case, dict):
            errors.append(f"{prefix} must be an object")
            continue
        case_id = case.get("id")
        if not _text(case_id):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(case_id)
        if not _text(case.get("expected")):
            errors.append(f"{prefix}.expected must be non-empty text")
        if not _text(case.get("source_test")):
            errors.append(f"{prefix}.source_test must be non-empty text")
        status = case.get("status")
        if not isinstance(status, str) or status not in CASE_STATUSES:
            errors.append(f"{prefix}.status must remain planned, pending, observed, or issue")
        allow_none = isinstance(status, str) and status in {"planned", "pending"}
        evidence = case.get("evidence")
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
        errors.append("cases.id values must be unique")
    if tuple(ids) != REQUIRED_CASES:
        errors.append("cases must exactly match the frozen persistence coverage order")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open OS gate."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("production_review_status") not in OPEN_STATUSES:
        errors.append("production_review_status must remain pending, not_performed, in_progress, or failed")
    if value.get("os_interruption_status") != "not_run":
        errors.append("os_interruption_status must remain not_run")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    for key in ("os_interruption_performed", "detached_contract_tests_only"):
        expected = key == "detached_contract_tests_only"
        if value.get(key) is not expected:
            errors.append(f"{key} must be {str(expected).lower()}")
    errors.extend(_validate_roster(value.get("setting_keys")))
    errors.extend(_validate_authority(value.get("authority")))
    errors.extend(_validate_cases(value.get("cases")))
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
        print("SETTINGS_PERSISTENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SETTINGS_PERSISTENCE_READY: OS interruption and production review remain open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
