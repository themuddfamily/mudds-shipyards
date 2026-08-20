#!/usr/bin/env python3
"""Validate provenance and listening claims for authored audio assets.

This is deliberately a manifest gate, not an audio-quality claim.  It makes
asset identity, redistribution rights, runtime routing, and the boundary
between automated evidence and a real listening pass explicit.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
LISTENING_STATUSES = {"PASS", "FAIL", "OUTSTANDING", "NOT_RUN"}
RIGHTS_STATUSES = {"project_original", "licensed", "permission_pending", "unknown"}
ROUTING_STATUSES = {"DECLARED", "CAPTURED", "NOT_RUN"}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _unique_texts(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_manifest(manifest: Any, label: str = "manifest") -> list[str]:
    """Return blocking errors without inferring rights or audibility."""
    if not isinstance(manifest, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("audit_id", "source_commit"):
        if not _text(manifest.get(key)):
            errors.append(f"{label}.{key} is required")

    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        errors.append(f"{label}.assets must be a non-empty array")
        assets = []
    seen_ids: set[str] = set()
    for index, asset in enumerate(assets):
        prefix = f"{label}.assets[{index}]"
        if not isinstance(asset, dict):
            errors.append(f"{prefix} must be an object")
            continue
        asset_id = asset.get("asset_id")
        if not _text(asset_id):
            errors.append(f"{prefix}.asset_id is required")
        elif asset_id in seen_ids:
            errors.append(f"{prefix}.asset_id is duplicated")
        else:
            seen_ids.add(asset_id)
        if not _unique_texts(asset.get("paths")):
            errors.append(f"{prefix}.paths must be a non-empty unique array")
        digest = asset.get("sha256")
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")

        rights = asset.get("rights")
        if not isinstance(rights, dict):
            errors.append(f"{prefix}.rights must be an object")
            rights = {}
        if rights.get("status") not in RIGHTS_STATUSES:
            errors.append(f"{prefix}.rights.status is invalid")
        for key in ("source", "license"):
            if not _text(rights.get(key)):
                errors.append(f"{prefix}.rights.{key} is required")
        if rights.get("redistributable") is not True:
            errors.append(f"{prefix}.rights.redistributable must be true for a shipped asset")
        if rights.get("status") in {"permission_pending", "unknown"}:
            errors.append(f"{prefix}.rights.status does not establish shipping rights")

        routing = asset.get("routing")
        if not isinstance(routing, dict):
            errors.append(f"{prefix}.routing must be an object")
            routing = {}
        if not _text(routing.get("bus")):
            errors.append(f"{prefix}.routing.bus is required")
        if routing.get("status") not in ROUTING_STATUSES:
            errors.append(f"{prefix}.routing.status is invalid")
        if routing.get("status") == "CAPTURED" and not _text(routing.get("evidence")):
            errors.append(f"{prefix}.routing.evidence is required for CAPTURED routing")

        listening = asset.get("human_listening")
        if not isinstance(listening, dict):
            errors.append(f"{prefix}.human_listening must be an object")
            listening = {}
        status = listening.get("status")
        if status not in LISTENING_STATUSES:
            errors.append(f"{prefix}.human_listening.status is invalid")
        if status == "PASS":
            for key in ("reviewer", "device", "notes"):
                if not _text(listening.get(key)):
                    errors.append(f"{prefix}.human_listening.{key} is required for PASS")
            if routing.get("status") != "CAPTURED":
                errors.append(f"{prefix}.human_listening.PASS requires CAPTURED routing evidence")
        elif status in {"OUTSTANDING", "NOT_RUN"} and not _text(listening.get("notes")):
            errors.append(f"{prefix}.human_listening.notes is required while listening is incomplete")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("AUTHORED_AUDIO_ASSET_AUDIT_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUTHORED_AUDIO_ASSET_AUDIT_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
