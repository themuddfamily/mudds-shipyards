#!/usr/bin/env python3
"""Validate detached crash-diagnostic and recovery evidence.

The report joins the existing ``SessionDiagnosticRecord`` privacy boundary
with the ``CrashRecoveryCoordinator`` marker lifecycle. It proves bounded
redaction, generation-safe recovery observations, and namespace-only atomic
persistence without claiming an OS crash hook, stack capture, uploader, or
native/packaged run.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "crash_diagnostic_recovery"
EVIDENCE_MODE = "detached_contract_fixture"
DIAGNOSTIC_POLICY = "session_diagnostic_record_v1"
RECOVERY_POLICY = "crash_recovery_coordinator_v1"
MAX_EVENTS = 64
MAX_UNCLEAN_STARTS = 3
REQUIRED_AUTHORITY_EXCLUSIONS = {
    "os_crash_capture",
    "filesystem_path_access",
    "stack_trace_capture",
    "uploader",
    "settings_application",
    "gameplay_recovery",
}


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _finite_nonnegative(value: Any) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(float(value)) and value >= 0


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _object(value: Any, path: str, errors: list[str]) -> dict[str, Any] | None:
    if not isinstance(value, dict):
        errors.append(f"{path} must be an object")
        return None
    return value


def _marker(marker: Any, label: str, errors: list[str]) -> dict[str, Any] | None:
    value = _object(marker, label, errors)
    if value is None:
        return None
    if value.get("state") not in {"clean", "running"}:
        errors.append(f"{label}.state must be clean or running")
    for key in ("session_id", "startup_generation", "unclean_start_count", "last_physics_tick"):
        if not _nonnegative_int(value.get(key)):
            errors.append(f"{label}.{key} must be a non-negative integer")
    if not _finite_nonnegative(value.get("last_elapsed_physics_seconds")):
        errors.append(f"{label}.last_elapsed_physics_seconds must be finite and non-negative")
    if value.get("state") == "running" and not _positive_int(value.get("session_id")):
        errors.append(f"{label}.session_id must be positive while running")
    if value.get("state") == "clean" and value.get("unclean_start_count") != 0:
        errors.append(f"{label}.unclean_start_count must be zero while clean")
    if isinstance(value.get("unclean_start_count"), int) and value["unclean_start_count"] > MAX_UNCLEAN_STARTS:
        errors.append(f"{label}.unclean_start_count exceeds the bounded policy")
    return value


def _validate_recovery_event(event: Any, recovery_marker: dict[str, Any] | None, errors: list[str]) -> None:
    value = _object(event, "recovery_event", errors)
    if value is None:
        return
    if value.get("event_code") != "crash_detected":
        errors.append("recovery_event.event_code must be crash_detected")
    if value.get("severity") != "error":
        errors.append("recovery_event.severity must be error")
    for key in ("session_id", "physics_tick"):
        if not _nonnegative_int(value.get(key)):
            errors.append(f"recovery_event.{key} must be a non-negative integer")
    if not _finite_nonnegative(value.get("session_elapsed_physics_seconds")):
        errors.append("recovery_event.session_elapsed_physics_seconds must be finite and non-negative")
    if recovery_marker is not None and value.get("session_id") != recovery_marker.get("session_id"):
        errors.append("recovery_event.session_id must match the recovered session")
    fields = _object(value.get("fields"), "recovery_event.fields", errors)
    if fields is not None:
        if set(fields) != {"attempt_count", "recovered"}:
            errors.append("recovery_event.fields must contain only attempt_count and recovered")
        if not _positive_int(fields.get("attempt_count")):
            errors.append("recovery_event.fields.attempt_count must be positive")
        if fields.get("recovered") is not True:
            errors.append("recovery_event.fields.recovered must be true")
        if recovery_marker is not None and fields.get("attempt_count") != recovery_marker.get("unclean_start_count"):
            errors.append("recovery_event attempt_count must match the recovery marker")
    if not _nonnegative_int(value.get("redacted_field_count")):
        errors.append("recovery_event.redacted_field_count must be non-negative")


def validate_evidence(report: Any, label: str = "evidence") -> list[str]:
    """Return structural, lifecycle, privacy, and authority-boundary errors."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    if report.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    if report.get("evidence_scope") != EVIDENCE_SCOPE:
        errors.append(f"{label}.evidence_scope must be {EVIDENCE_SCOPE}")
    if report.get("evidence_mode") != EVIDENCE_MODE:
        errors.append(f"{label}.evidence_mode must be {EVIDENCE_MODE}")
    if report.get("diagnostic_policy") != DIAGNOSTIC_POLICY:
        errors.append(f"{label}.diagnostic_policy must be {DIAGNOSTIC_POLICY}")
    if report.get("recovery_policy") != RECOVERY_POLICY:
        errors.append(f"{label}.recovery_policy must be {RECOVERY_POLICY}")
    for key in ("native_claims", "uses_os_crash_hook", "uploader_invoked", "stack_trace_retained"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("source_revision", "fixture_description"):
        if not _text(report.get(key)):
            errors.append(f"{label}.{key} must be non-empty text")

    initial = _marker(report.get("initial_marker"), f"{label}.initial_marker", errors)
    recovery = _marker(report.get("recovery_marker"), f"{label}.recovery_marker", errors)
    clean = _marker(report.get("clean_marker"), f"{label}.clean_marker", errors)
    if initial is not None and recovery is not None:
        if initial.get("state") != "running":
            errors.append(f"{label}.initial_marker.state must be running")
        if recovery.get("state") != "running":
            errors.append(f"{label}.recovery_marker.state must be running")
        if recovery.get("startup_generation", 0) <= initial.get("startup_generation", 0):
            errors.append(f"{label}.recovery_marker.startup_generation must advance")
        if recovery.get("unclean_start_count") != initial.get("unclean_start_count", 0) + 1:
            errors.append(f"{label}.recovery_marker must increment unclean_start_count exactly once")
    if recovery is not None and clean is not None:
        if clean.get("state") != "clean":
            errors.append(f"{label}.clean_marker.state must be clean")
        if clean.get("startup_generation") != recovery.get("startup_generation"):
            errors.append(f"{label}.clean_marker must retain recovered startup generation")
        if clean.get("session_id") != recovery.get("session_id"):
            errors.append(f"{label}.clean_marker must close the recovered session")
    _validate_recovery_event(report.get("recovery_event"), recovery, errors)

    retention = _object(report.get("retention"), f"{label}.retention", errors)
    if retention is not None:
        if retention.get("capacity") != MAX_EVENTS:
            errors.append(f"{label}.retention.capacity must be {MAX_EVENTS}")
        for key in ("observed_event_count", "dropped_event_count", "next_sequence"):
            if not _nonnegative_int(retention.get(key)):
                errors.append(f"{label}.retention.{key} must be a non-negative integer")
        if isinstance(retention.get("observed_event_count"), int) and retention["observed_event_count"] > MAX_EVENTS:
            errors.append(f"{label}.retention.observed_event_count exceeds capacity")
        if retention.get("dropped_event_count", 0) > 0 and retention.get("observed_event_count") != MAX_EVENTS:
            errors.append(f"{label}.retention overflow must retain exactly capacity events")
        if isinstance(retention.get("next_sequence"), int) and isinstance(retention.get("observed_event_count"), int) and retention["next_sequence"] <= retention["observed_event_count"]:
            errors.append(f"{label}.retention.next_sequence must follow retained events")

    privacy = _object(report.get("privacy"), f"{label}.privacy", errors)
    if privacy is not None:
        for key in ("secret_fields_redacted", "private_text_rejected", "paths_rejected", "arbitrary_fields_rejected", "retained_values_are_primitive"):
            if privacy.get(key) is not True:
                errors.append(f"{label}.privacy.{key} must be true")
        if privacy.get("retained_field_vocabulary") != [
            "attempt_count", "damage_ratio", "duration_physics_seconds", "entity_count",
            "error_code", "frame_delta_seconds", "input_device_code", "peer_count",
            "recovered", "speed_metres_per_second",
        ]:
            errors.append(f"{label}.privacy.retained_field_vocabulary drifted")

    persistence = _object(report.get("atomic_persistence"), f"{label}.atomic_persistence", errors)
    if persistence is not None:
        if persistence.get("namespace") != "session_diagnostics":
            errors.append(f"{label}.atomic_persistence.namespace must be session_diagnostics")
        for key in ("injected_store", "generation_fenced", "failed_write_preserves_existing"):
            if persistence.get(key) is not True:
                errors.append(f"{label}.atomic_persistence.{key} must be true")
        if persistence.get("merges_unrelated_namespaces") is not False:
            errors.append(f"{label}.atomic_persistence.merges_unrelated_namespaces must be false")

    authority = _object(report.get("authority_exclusions"), f"{label}.authority_exclusions", errors)
    if authority is not None:
        if set(authority) != REQUIRED_AUTHORITY_EXCLUSIONS:
            errors.append(f"{label}.authority_exclusions must exactly list the excluded authorities")
        for key in REQUIRED_AUTHORITY_EXCLUSIONS:
            if authority.get(key) is not False:
                errors.append(f"{label}.authority_exclusions.{key} must be false")
    return errors


def validate_evidence_file(report_path: str | Path) -> list[str]:
    path = Path(report_path)
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {path}: {exc}"]
    return validate_evidence(report, str(path))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("evidence", type=Path)
    args = parser.parse_args(argv)
    errors = validate_evidence_file(args.evidence)
    if errors:
        print("CRASH_DIAGNOSTIC_RECOVERY_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("CRASH_DIAGNOSTIC_RECOVERY_READY: OS capture and uploader remain external")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
