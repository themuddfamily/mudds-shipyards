#!/usr/bin/env python3
"""Validate v19 cleanup authority-to-digest binding summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_authority_digest_binding_summary_v19"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
REQUIRED_EXCLUSIONS = {"gameplay_damage", "gameplay_phase", "reward"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle", "canonicalization"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_AUTHORITY_DIGEST_BINDING_ONLY":
        errors.append("claim must be AUTOMATED_AUTHORITY_DIGEST_BINDING_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")

    bindings = summary.get("bindings")
    ids: set[str] = set()
    digests: set[str] = set()
    if not isinstance(bindings, list) or not bindings:
        errors.append("bindings must be a non-empty array")
        bindings = []
    for index, binding in enumerate(bindings):
        prefix = f"bindings[{index}]"
        if not isinstance(binding, dict):
            errors.append(f"{prefix} must be an object")
            continue
        binding_id = binding.get("binding_id")
        if not _text(binding_id):
            errors.append(f"{prefix}.binding_id is required")
        elif binding_id in ids:
            errors.append(f"{prefix}.binding_id is duplicated")
        else:
            ids.add(binding_id)
        digest = binding.get("manifest_sha256")
        if not _digest(digest):
            errors.append(f"{prefix}.manifest_sha256 must be a lowercase 64-character digest")
        else:
            digests.add(digest)
        if not _digest(binding.get("authority_sha256")):
            errors.append(f"{prefix}.authority_sha256 must be a lowercase 64-character digest")
        if binding.get("authority") != "presentation_only":
            errors.append(f"{prefix}.authority must be presentation_only")
        exclusions = binding.get("authority_exclusions")
        if not isinstance(exclusions, list) or not REQUIRED_EXCLUSIONS.issubset(exclusions):
            errors.append(f"{prefix}.authority_exclusions must include gameplay_damage, gameplay_phase, and reward")
        if not _text(binding.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if binding.get("bound") is not True:
            errors.append(f"{prefix}.bound must be true")
    if summary.get("binding_count") != len(bindings):
        errors.append("binding_count must match bindings length")
    if not _digest(summary.get("consensus_manifest_sha256")):
        errors.append("consensus_manifest_sha256 must be a lowercase 64-character digest")
    elif digests and summary["consensus_manifest_sha256"] not in digests:
        errors.append("consensus_manifest_sha256 must match a binding manifest_sha256")
    if summary.get("binding_pass") is not True:
        errors.append("binding_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_AUTHORITY_BINDING_V19_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_AUTHORITY_BINDING_V19_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
