#!/usr/bin/env python3
"""Validate bounded multicrew-role review evidence without runtime effects."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "multicrew_role_review_v1006"
VERSION = 1006
OPEN = {"pending", "not_performed"}
ROLES = {"pilot", "gunner", "passenger", "engineer"}
EXCLUDED = {"native_render", "human_signoff", "runtime_role_assignment", "live_multiplayer_claim"}
POLICY_NAMES = ("write", "process", "network", "environment", "filesystem", "time", "random", "thread", "signal", "mutex", "ipc", "subprocess", "ui", "audio", "haptic", "display", "input", "storage", "cache", "gpu", "sensor")
POLICIES = {f"runtime_{name}_policy": "forbidden" for name in POLICY_NAMES}
FIXED = {"review_scope": "multicrew_role", "evidence_phase": "review", "review_mode": "evidence_only", "authority_class": "non_runtime_review", "closure_state": "open", "gate_policy": "native_human_open", "evidence_boundary": "pre_native_human", "evidence_revision": "v1006"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _gate(value: Any, label: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{label} must be an object")
    elif value.get("status") not in OPEN:
        errors.append(f"{label}.status must remain open")


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    if value.get("schema_version") != VERSION:
        errors.append(f"{label}.schema_version must be {VERSION}")
    for key in ("world_id", "vessel_id", "review_id", "source_revision", "root_id"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    for key, wanted in {**FIXED, **POLICIES}.items():
        if value.get(key) != wanted:
            errors.append(f"{label}.{key} must be {wanted}")
    if value.get("review_version") != VERSION:
        errors.append(f"{label}.review_version must be {VERSION}")
    if value.get("root_identity_value") != value.get("root_id"):
        errors.append(f"{label}.root_identity_value must match root_id")
    roles = value.get("roles")
    if not isinstance(roles, list) or len(roles) != 4:
        errors.append(f"{label}.roles must contain exactly four roles")
        roles = roles if isinstance(roles, list) else []
    ids: set[str] = set(); seen: set[str] = set()
    expected = {**FIXED, **POLICIES}
    for index, role in enumerate(roles):
        prefix = f"{label}.roles[{index}]"
        if not isinstance(role, dict):
            errors.append(f"{prefix} must be an object")
            continue
        role_id = role.get("role_id")
        if not _text(role_id) or role_id in ids:
            errors.append(f"{prefix}.role_id must be unique and required")
        if _text(role_id): ids.add(role_id)
        kind = role.get("role")
        if kind not in ROLES:
            errors.append(f"{prefix}.role must be a supported crew role")
        else:
            if kind in seen:
                errors.append(f"{prefix}.role must be unique")
            seen.add(kind)
        for key in ("seat_id", "evidence_id"):
            if not _text(role.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if role.get("review_version") != VERSION:
            errors.append(f"{prefix}.review_version must be {VERSION}")
        for key, wanted in expected.items():
            if role.get(key) != wanted:
                errors.append(f"{prefix}.{key} must match manifest")
        if role.get("review_id") != value.get("review_id"):
            errors.append(f"{prefix}.review_id must match manifest")
        if role.get("vessel_id") != value.get("vessel_id"):
            errors.append(f"{prefix}.vessel_id must match manifest")
        if role.get("source_revision") != value.get("source_revision"):
            errors.append(f"{prefix}.source_revision must match manifest")
        if role.get("root_identity_value") != value.get("root_identity_value"):
            errors.append(f"{prefix}.root_identity_value must match manifest")
        if role.get("runtime_authority") is not False:
            errors.append(f"{prefix}.runtime_authority must be false")
        if role.get("status") not in OPEN:
            errors.append(f"{prefix}.status must remain open")
    if seen != ROLES:
        errors.append(f"{label}.roles must cover pilot, gunner, passenger, and engineer")
    _gate(value.get("native_render"), f"{label}.native_render", errors)
    _gate(value.get("human_signoff"), f"{label}.human_signoff", errors)
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not EXCLUDED.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def validate(path: str | Path) -> list[str]:
    try:
        return validate_manifest(json.loads(Path(path).read_text(encoding="utf-8")))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("manifest", type=Path)
    errors = validate(parser.parse_args(argv).manifest)
    if errors:
        print("MULTICREW_ROLE_REVIEW_V1006_INVALID"); print("\n".join(f"- {error}" for error in errors)); return 1
    print("MULTICREW_ROLE_REVIEW_V1006_VALID_OPEN"); return 0


if __name__ == "__main__":
    raise SystemExit(main())
