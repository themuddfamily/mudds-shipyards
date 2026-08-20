#!/usr/bin/env python3
"""Validate a planetary hazard/landmark visual digest manifest."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_landmark_visual_digest_manifest_validator_v1"
OPEN = {"pending", "not_performed"}
SHA256 = re.compile(r"^[0-9a-fA-F]{64}$")
KINDS = {"hazard", "landmark", "route"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_manifest(value: Any, label: str = "manifest") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    if not _text(value.get("world_id")) or not _text(value.get("source_revision")):
        errors.append(f"{label}.world_id and source_revision are required")
    artifacts = value.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        errors.append(f"{label}.artifacts must contain digest artifacts")
        artifacts = []
    ids: set[str] = set()
    kinds: set[str] = set()
    for index, artifact in enumerate(artifacts):
        prefix = f"{label}.artifacts[{index}]"
        if not isinstance(artifact, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = artifact.get("id")
        if not _text(ident) or ident in ids:
            errors.append(f"{prefix}.id must be unique")
        ids.add(ident)
        kind = artifact.get("kind")
        if kind not in KINDS:
            errors.append(f"{prefix}.kind is invalid")
        kinds.add(kind)
        if not _text(artifact.get("path")) or not artifact["path"].startswith("res://"):
            errors.append(f"{prefix}.path must be a res:// path")
        if not isinstance(artifact.get("sha256"), str) or not SHA256.fullmatch(artifact["sha256"]):
            errors.append(f"{prefix}.sha256 must be a 64-character digest")
        if artifact.get("verification_status") not in OPEN:
            errors.append(f"{prefix}.verification_status must remain open")
    if not KINDS.issubset(kinds):
        errors.append(f"{label}.artifacts must cover hazard, landmark, and route")
    aggregate = value.get("aggregate_verification")
    if not isinstance(aggregate, dict) or aggregate.get("status") not in OPEN:
        errors.append(f"{label}.aggregate_verification.status must remain open")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"artifact_verification", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_DIGEST_MANIFEST_VALIDATOR_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_DIGEST_MANIFEST_VALIDATOR_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
