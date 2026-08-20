#!/usr/bin/env python3
"""Validate consistency between UI audio cue prompts and caption fallbacks."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA = "audio_caption_prompt_consistency_v1"
REQUIRED_CATEGORIES = {"interaction", "warning", "combat", "navigation"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _unique_texts(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(_text(item) for item in value) and len(value) == len(set(value))


def validate_manifest(manifest: Any) -> list[str]:
    if not isinstance(manifest, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if manifest.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "prompt_owner", "evidence_bundle"):
        if not _text(manifest.get(key)):
            errors.append(f"{key} is required")
    if manifest.get("hardware_review") != "OPEN":
        errors.append("hardware_review must be OPEN")
    if manifest.get("claim") != "AUTOMATED_CONSISTENCY_ONLY":
        errors.append("claim must be AUTOMATED_CONSISTENCY_ONLY")

    prompts = manifest.get("prompts")
    if not isinstance(prompts, list) or not prompts:
        errors.append("prompts must be a non-empty array")
        prompts = []
    ids: set[str] = set()
    categories: set[str] = set()
    for index, prompt in enumerate(prompts):
        prefix = f"prompts[{index}]"
        if not isinstance(prompt, dict):
            errors.append(f"{prefix} must be an object")
            continue
        cue_id = prompt.get("cue_id")
        if not _text(cue_id):
            errors.append(f"{prefix}.cue_id is required")
        elif cue_id in ids:
            errors.append(f"{prefix}.cue_id is duplicated")
        else:
            ids.add(cue_id)
        category = prompt.get("category")
        if category not in REQUIRED_CATEGORIES:
            errors.append(f"{prefix}.category is invalid")
        else:
            categories.add(category)
        for key in ("audio_route", "caption_category", "caption_text", "visual_token", "evidence"):
            if not _text(prompt.get(key)):
                errors.append(f"{prefix}.{key} is required")
        if prompt.get("audio_route") == "":
            errors.append(f"{prefix}.audio_route is required")
        if prompt.get("caption_category") != category:
            errors.append(f"{prefix}.caption_category must match category")
        if prompt.get("visual_token") in {"", "colour_only", "color_only"}:
            errors.append(f"{prefix}.visual_token must be a non-colour cue")
        channels = prompt.get("fallback_channels")
        if not _unique_texts(channels) or not {"captions", "visual_state"}.issubset(channels):
            errors.append(f"{prefix}.fallback_channels must include unique captions and visual_state")
    missing = REQUIRED_CATEGORIES - categories
    if missing:
        errors.append(f"prompts must cover: {', '.join(sorted(missing))}")
    if not _text(manifest.get("boundary_note")):
        errors.append("boundary_note is required for automated consistency evidence")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CAPTION_PROMPT_CONSISTENCY_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CAPTION_PROMPT_CONSISTENCY_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
