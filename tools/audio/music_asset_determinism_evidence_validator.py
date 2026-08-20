#!/usr/bin/env python3
"""Validate provenance and loop-determinism evidence for authored music assets."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "music_asset_determinism_evidence_v1"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def validate_manifest(manifest: Any) -> list[str]:
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "generator", "generator_version", "evidence_bundle"):
        if not _text(manifest.get(key)):
            errors.append(f"{key} is required")
    if manifest.get("seed") != 0:
        errors.append("seed must be the fixed value 0")
    if manifest.get("human_audition") != "OPEN":
        errors.append("human_audition must be OPEN")
    if not _text(manifest.get("audition_boundary")):
        errors.append("audition_boundary is required")

    assets = manifest.get("assets")
    if not isinstance(assets, list) or not assets:
        errors.append("assets must be a non-empty array")
        assets = []
    ids: set[str] = set()
    for index, asset in enumerate(assets):
        prefix = f"assets[{index}]"
        if not isinstance(asset, dict):
            errors.append(f"{prefix} must be an object")
            continue
        asset_id = asset.get("asset_id")
        if not _text(asset_id):
            errors.append(f"{prefix}.asset_id is required")
        elif asset_id in ids:
            errors.append(f"{prefix}.asset_id is duplicated")
        else:
            ids.add(asset_id)
        if not _text(asset.get("path")):
            errors.append(f"{prefix}.path is required")
        digest = asset.get("sha256")
        if not isinstance(digest, str) or not SHA256_RE.fullmatch(digest):
            errors.append(f"{prefix}.sha256 must be a lowercase 64-character digest")
        for key in ("sample_rate_hz", "channels", "frame_count"):
            if not _positive_int(asset.get(key)):
                errors.append(f"{prefix}.{key} must be a positive integer")
        if asset.get("channels") != 1:
            errors.append(f"{prefix}.channels must be mono (1)")
        if asset.get("sample_rate_hz") != 48000:
            errors.append(f"{prefix}.sample_rate_hz must be 48000")
        if asset.get("loop_mode") != "forward_seamless":
            errors.append(f"{prefix}.loop_mode must be forward_seamless")
        for key in ("generation_evidence", "loop_evidence"):
            if not _text(asset.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if asset.get("regenerated_sha256") != digest:
            errors.append(f"{prefix}.regenerated_sha256 must match sha256")
    if manifest.get("claim") != "AUTOMATED_DETERMINISM_ONLY":
        errors.append("claim must be AUTOMATED_DETERMINISM_ONLY")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("MUSIC_ASSET_DETERMINISM_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("MUSIC_ASSET_DETERMINISM_EVIDENCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
