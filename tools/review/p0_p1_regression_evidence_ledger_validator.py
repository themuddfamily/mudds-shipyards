#!/usr/bin/env python3
"""Validate the P0/P1 defect and regression-evidence ledger.

This is a stabilization handoff gate. It checks the intake fields required by
the roadmap and prevents a P0/P1 from being called closed without before/after
regression, focused/full matrix, current-package, and independent-verification
evidence. It does not run tests, launch a package, or infer that a referenced
file exists.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "p0_p1_regression_evidence_ledger_v1"
SEVERITIES = {"P0", "P1"}
STATUSES = {
    "CANDIDATE", "NEW", "REPRODUCED", "FIXING", "VERIFYING", "CLOSED",
    "NOT_REPRODUCED", "ACCEPTED_RISK",
}
STATUS_ORDER = {
    "CANDIDATE": 0,
    "NEW": 1,
    "REPRODUCED": 2,
    "FIXING": 3,
    "VERIFYING": 4,
}
TERMINAL_STATUSES = {"CLOSED", "NOT_REPRODUCED", "ACCEPTED_RISK"}
EVIDENCE_KINDS = {"log", "image", "video", "report"}
SHA256 = re.compile(r"^[0-9a-f]{40,64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _hash(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256.fullmatch(value))


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _nonnegative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _required_text(mapping: dict[str, Any], key: str, prefix: str, errors: list[str]) -> Any:
    value = mapping.get(key)
    if not _text(value):
        errors.append(f"{prefix}.{key} must be non-empty text")
    return value


def _validate_environment(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object")
        return
    for key in ("os", "cpu", "gpu", "ram", "driver", "audio", "input", "resolution", "profile"):
        _required_text(value, key, prefix, errors)
    if not isinstance(value.get("user_data_state"), str) or value.get("user_data_state") not in {"clean", "retained", "fresh", "unknown"}:
        errors.append(f"{prefix}.user_data_state must be clean, retained, fresh, or unknown")


def _validate_references(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, list) or not value:
        errors.append(f"{prefix} must contain one or more evidence references")
        return
    seen: set[tuple[str, str]] = set()
    for index, reference in enumerate(value):
        label = f"{prefix}[{index}]"
        if not isinstance(reference, dict):
            errors.append(f"{label} must be an object")
            continue
        if not isinstance(reference.get("kind"), str) or reference.get("kind") not in EVIDENCE_KINDS:
            errors.append(f"{label}.kind must be log, image, video, or report")
        path = _required_text(reference, "path", label, errors)
        digest = reference.get("sha256")
        if not _hash(digest):
            errors.append(f"{label}.sha256 must be a lowercase SHA-256 digest")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier evidence reference")
            seen.add(identity)


def _validate_frequency(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object")
        return
    failures = value.get("failures")
    attempts = value.get("attempts")
    configurations = value.get("configurations")
    if not _nonnegative_int(failures) or not _positive_int(attempts):
        errors.append(f"{prefix}.failures must be non-negative and attempts must be positive integers")
    elif failures > attempts:
        errors.append(f"{prefix}.failures cannot exceed attempts")
    if not isinstance(configurations, list) or any(not _text(item) for item in configurations):
        errors.append(f"{prefix}.configurations must contain unique non-empty names")
    elif len(configurations) != len(set(configurations)):
        errors.append(f"{prefix}.configurations must contain unique non-empty names")


def _validate_reproduction(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object")
        return
    steps = value.get("steps")
    if not isinstance(steps, list) or not steps or any(not _text(item) for item in steps):
        errors.append(f"{prefix}.steps must contain numbered non-empty steps")
    for key in ("expected", "actual", "loop_beat"):
        _required_text(value, key, prefix, errors)
    _validate_frequency(value.get("failure_frequency"), f"{prefix}.failure_frequency", errors)
    _validate_references(value.get("evidence"), f"{prefix}.evidence", errors)


def _validate_closure(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object for a closed P0/P1")
        return
    _required_text(value, "regression_test", prefix, errors)
    if value.get("before_failing") is not True:
        errors.append(f"{prefix}.before_failing must be true")
    if value.get("after_green") is not True:
        errors.append(f"{prefix}.after_green must be true")
    for key in ("focused_matrix", "full_matrix", "current_package_rerun", "independent_verification"):
        evidence = value.get(key)
        label = f"{prefix}.{key}"
        if not isinstance(evidence, dict):
            errors.append(f"{label} must be an object")
            continue
        if evidence.get("status") != "passed":
            errors.append(f"{label}.status must be passed")
        _required_text(evidence, "evidence", label, errors)


def _validate_status_history(value: Any, status: str, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or item not in STATUSES for item in value):
        errors.append(f"{prefix} must contain a non-empty valid status history")
        return
    if value[-1] != status:
        errors.append(f"{prefix} must end at the item's current status")
    if len(value) != len(set(value)):
        errors.append(f"{prefix} must not repeat statuses")
    previous_rank = -1
    for item in value:
        if item in STATUS_ORDER:
            rank = STATUS_ORDER[item]
            if rank < previous_rank:
                errors.append(f"{prefix} cannot move backward from {previous_rank} to {rank}")
            previous_rank = max(previous_rank, rank)
    if status == "CLOSED" and "VERIFYING" not in value:
        errors.append(f"{prefix} must include VERIFYING before CLOSED")


def _validate_item(item: Any, index: int) -> list[str]:
    prefix = f"items[{index}]"
    if not isinstance(item, dict):
        return [f"{prefix} must be an object"]
    errors: list[str] = []
    item_id = _required_text(item, "id", prefix, errors)
    if not isinstance(item.get("severity"), str) or item.get("severity") not in SEVERITIES:
        errors.append(f"{prefix}.severity must be P0 or P1")
    status = item.get("status")
    if not isinstance(status, str) or status not in STATUSES:
        errors.append(f"{prefix}.status is unsupported")
    _required_text(item, "title", prefix, errors)
    _required_text(item, "reporter", prefix, errors)
    _required_text(item, "reported_at", prefix, errors)
    _required_text(item, "owner", prefix, errors)
    _required_text(item, "disposition", prefix, errors)
    _validate_status_history(item.get("status_history"), status, f"{prefix}.status_history", errors)

    source = item.get("source_artifacts")
    if not isinstance(source, dict):
        errors.append(f"{prefix}.source_artifacts must be an object")
    else:
        for key in ("first_source_hash", "last_source_hash", "first_artifact_hash", "last_artifact_hash"):
            if not _hash(source.get(key)):
                errors.append(f"{prefix}.source_artifacts.{key} must be a lowercase SHA-256 digest")
    _validate_environment(item.get("environment"), f"{prefix}.environment", errors)
    _validate_reproduction(item.get("reproduction"), f"{prefix}.reproduction", errors)

    regression = item.get("linked_regression")
    if not isinstance(regression, dict):
        errors.append(f"{prefix}.linked_regression must be an object")
    else:
        _required_text(regression, "path", f"{prefix}.linked_regression", errors)
        _required_text(regression, "name", f"{prefix}.linked_regression", errors)

    if status == "CLOSED":
        _validate_closure(item.get("closure"), f"{prefix}.closure", errors)
    elif status == "ACCEPTED_RISK":
        if not _text(item.get("risk_rationale")):
            errors.append(f"{prefix}.risk_rationale is required for ACCEPTED_RISK")
        if not _text(item.get("risk_owner")):
            errors.append(f"{prefix}.risk_owner is required for ACCEPTED_RISK")
    elif status == "NOT_REPRODUCED":
        frequency = item.get("reproduction", {}).get("failure_frequency", {}) if isinstance(item.get("reproduction"), dict) else {}
        if frequency.get("failures") != 0:
            errors.append(f"{prefix}.NOT_REPRODUCED requires zero failures")
        if frequency.get("attempts", 0) < 10:
            errors.append(f"{prefix}.NOT_REPRODUCED requires at least ten attempts")
        configurations = frequency.get("configurations", [])
        if not isinstance(configurations, list) or len(configurations) < 2:
            errors.append(f"{prefix}.NOT_REPRODUCED requires two documented configurations")
    elif isinstance(status, str) and status in {"REPRODUCED", "FIXING", "VERIFYING"}:
        frequency = item.get("reproduction", {}).get("failure_frequency", {}) if isinstance(item.get("reproduction"), dict) else {}
        if frequency.get("failures", 0) < 1:
            errors.append(f"{prefix}.{status} requires a failing reproduction witness")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the ledger is coherent."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("ledger_revision", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    if not isinstance(value.get("full_matrix_status"), str) or value.get("full_matrix_status") not in {"not_run", "passed"}:
        errors.append("full_matrix_status must be not_run or passed")
    items = value.get("items")
    if not isinstance(items, list) or not items:
        return errors + ["items must contain one or more P0/P1 records"]
    ids: list[str] = []
    for index, item in enumerate(items):
        if isinstance(item, dict) and _text(item.get("id")):
            ids.append(item["id"])
        errors.extend(_validate_item(item, index))
    if len(ids) != len(set(ids)):
        errors.append("items.id values must be unique")
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
        print("P0_P1_REGRESSION_LEDGER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("P0_P1_REGRESSION_LEDGER_READY: full matrix status remains explicit")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
