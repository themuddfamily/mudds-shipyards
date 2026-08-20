#!/usr/bin/env python3
"""Validate the station's embodied-player geometry audit handoff.

This ledger freezes the five station route viewpoints and the geometry defect
categories that each player/ship perspective must cover.  It is deliberately
not a renderer, physics probe, or human sign-off: detached validation keeps
the native playtest gate open and cannot turn a planned capture into proof.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "station_embodied_geometry_audit_v1"
HUMAN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
RESULTS = {"pending", "clear", "issue", "not_assessed"}
PERSPECTIVES = ("embodied_player", "ship")
LOCATIONS = ("central", "aft", "habitat", "freight", "fleet_dock")
ROUTES = {
    "central": "spawn_to_central",
    "aft": "central_to_aft",
    "habitat": "central_to_habitat",
    "freight": "central_to_freight",
    "fleet_dock": "central_to_fleet_dock",
}
CATEGORIES = (
    "clipping",
    "camera_near_plane_intrusion",
    "z_fighting",
    "invisible_blocker",
    "collision_free_dressing",
    "inaccessible_route",
    "flashing_material_or_light",
    "lifecycle_phantom_geometry",
)
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
        path = reference.get("path")
        digest = reference.get("sha256")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier reference")
            seen.add(identity)


def _expected_viewpoint_ids() -> tuple[str, ...]:
    return tuple(f"{location}-{perspective}" for location in LOCATIONS for perspective in PERSPECTIVES)


def _validate_viewpoints(value: Any) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    ids: list[str] = []
    if not isinstance(value, list) or len(value) != len(_expected_viewpoint_ids()):
        return ["viewpoints must contain exactly ten station/player and station/ship viewpoints"], []
    expected = set(_expected_viewpoint_ids())
    for index, viewpoint in enumerate(value):
        prefix = f"viewpoints[{index}]"
        if not isinstance(viewpoint, dict):
            errors.append(f"{prefix} must be an object")
            continue
        identifier = viewpoint.get("id")
        if not _text(identifier):
            errors.append(f"{prefix}.id must be non-empty text")
        else:
            ids.append(identifier)
        location = viewpoint.get("location")
        if location not in LOCATIONS:
            errors.append(f"{prefix}.location must be one of the five station locations")
        perspective = viewpoint.get("perspective")
        if perspective not in PERSPECTIVES:
            errors.append(f"{prefix}.perspective must be embodied_player or ship")
        if isinstance(location, str) and location in ROUTES and viewpoint.get("route") != ROUTES[location]:
            errors.append(f"{prefix}.route must match the location's frozen route")
        if not _text(viewpoint.get("location_label")):
            errors.append(f"{prefix}.location_label must be non-empty text")
    if len(ids) != len(set(ids)):
        errors.append("viewpoints.id values must be unique")
    if set(ids) != expected:
        errors.append("viewpoints must exactly cover both perspectives at all five locations")
    return errors, ids


def _validate_observations(value: Any, viewpoint_ids: list[str]) -> list[str]:
    errors: list[str] = []
    expected_keys = {
        (viewpoint_id, category)
        for viewpoint_id in _expected_viewpoint_ids()
        for category in CATEGORIES
    }
    if not isinstance(value, list) or len(value) != len(expected_keys):
        return ["observations must contain exactly one row for every viewpoint/category pair"]
    seen: set[tuple[Any, Any]] = set()
    evidence_seen: set[tuple[str, str]] = set()
    for index, observation in enumerate(value):
        prefix = f"observations[{index}]"
        if not isinstance(observation, dict):
            errors.append(f"{prefix} must be an object")
            continue
        viewpoint = observation.get("viewpoint")
        category = observation.get("category")
        if viewpoint not in viewpoint_ids:
            errors.append(f"{prefix}.viewpoint must reference a declared viewpoint")
        if category not in CATEGORIES:
            errors.append(f"{prefix}.category must be one of the frozen geometry categories")
        # Normalize malformed non-string values before using them as a set key;
        # a review manifest must report errors rather than crash on bad JSON.
        key = (
            viewpoint if isinstance(viewpoint, str) else repr(viewpoint),
            category if isinstance(category, str) else repr(category),
        )
        if key in seen:
            errors.append(f"{prefix} duplicates an earlier viewpoint/category pair")
        seen.add(key)
        result = observation.get("result")
        if not isinstance(result, str) or result not in RESULTS:
            errors.append(f"{prefix}.result must be pending, clear, issue, or not_assessed")
        evidence = observation.get("evidence")
        if isinstance(result, str) and result in {"pending", "not_assessed"}:
            _references(evidence, f"{prefix}.evidence", errors, allow_none=True)
        else:
            _references(evidence, f"{prefix}.evidence", errors, allow_none=False)
        if isinstance(evidence, list):
            for reference in evidence:
                if not isinstance(reference, dict):
                    continue
                path = reference.get("path")
                digest = reference.get("sha256")
                if isinstance(path, str) and isinstance(digest, str) and _sha(digest):
                    identity = (path, digest)
                    if identity in evidence_seen:
                        errors.append(f"{prefix}.evidence duplicates an earlier ledger reference")
                    evidence_seen.add(identity)
    if seen != expected_keys:
        errors.append("observations must exactly cover every viewpoint/category pair")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open human gate."""
    if not isinstance(value, dict):
        return ["ledger must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if value.get("human_review_status") not in HUMAN_STATUSES:
        errors.append("human_review_status must remain pending, not_performed, in_progress, or failed")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(f"{key} must be non-empty text")
    if value.get("human_review_complete") is not False:
        errors.append("human_review_complete must remain false")
    if value.get("native_run_performed") is not False:
        errors.append("native_run_performed must remain false")
    if value.get("detached_contract_tests_only") is not True:
        errors.append("detached_contract_tests_only must be true")
    viewpoint_errors, viewpoint_ids = _validate_viewpoints(value.get("viewpoints"))
    errors.extend(viewpoint_errors)
    errors.extend(_validate_observations(value.get("observations"), viewpoint_ids))
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
        print("STATION_EMBODIED_GEOMETRY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("STATION_EMBODIED_GEOMETRY_READY: native/human geometry review remains open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
