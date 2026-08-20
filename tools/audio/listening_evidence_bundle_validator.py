#!/usr/bin/env python3
"""Validate a cross-feature audio listening/evidence bundle.

The bundle joins authored music, runtime mix, and caption/accessibility review
without pretending that headless audio or a caption layout test is a human
listening pass.  It is intentionally a claim boundary: each unfinished review
must carry an explicit note and every native listening claim must identify its
device and evidence.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
STATUSES = {"PASS", "FAIL", "OUTSTANDING", "NOT_RUN"}
BACKENDS = {"native_output", "dummy", "unknown"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _strings(value: Any, *, non_empty: bool = True) -> bool:
    return (
        isinstance(value, list)
        and (bool(value) or not non_empty)
        and all(_text(item) for item in value)
        and len(value) == len(set(value))
    )


def _review(errors: list[str], value: Any, prefix: str, *, native_required: bool = False) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object")
        return
    status = value.get("status")
    if status not in STATUSES:
        errors.append(f"{prefix}.status is invalid")
    if status == "PASS":
        for key in ("reviewer", "device", "evidence", "notes"):
            if not _text(value.get(key)):
                errors.append(f"{prefix}.{key} is required for PASS")
        if native_required and value.get("backend") != "native_output":
            errors.append(f"{prefix}.PASS requires native_output")
    elif status in {"OUTSTANDING", "NOT_RUN"} and not _text(value.get("notes")):
        errors.append(f"{prefix}.notes is required while review is incomplete")


def validate_bundle(bundle: Any, label: str = "bundle") -> list[str]:
    """Return blocking schema and claim-safety errors for one bundle."""
    if not isinstance(bundle, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if bundle.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("build_label", "source_commit", "bundle_id"):
        if not _text(bundle.get(key)):
            errors.append(f"{label}.{key} is required")

    music = bundle.get("music")
    if not isinstance(music, dict):
        errors.append(f"{label}.music must be an object")
        music = {}
    if not _strings(music.get("asset_ids")):
        errors.append(f"{label}.music.asset_ids must be a non-empty unique array")
    if music.get("bus") != "Music":
        errors.append(f"{label}.music.bus must be Music")
    required_states = {"station_rest", "encounter", "return"}
    states = music.get("state_checks")
    if not _strings(states):
        errors.append(f"{label}.music.state_checks must be a non-empty unique array")
    elif not required_states.issubset(states):
        errors.append(f"{label}.music.state_checks must cover station_rest, encounter, and return")
    if not _text(music.get("lifecycle_evidence")):
        errors.append(f"{label}.music.lifecycle_evidence is required")
    _review(errors, music.get("listening"), f"{label}.music.listening", native_required=True)

    mix = bundle.get("mix")
    if not isinstance(mix, dict):
        errors.append(f"{label}.mix must be an object")
        mix = {}
    backend = mix.get("backend")
    if backend not in BACKENDS:
        errors.append(f"{label}.mix.backend is invalid")
    if backend == "native_output" and not _text(mix.get("device")):
        errors.append(f"{label}.mix.device is required for native_output")
    if not _strings(mix.get("scenarios")):
        errors.append(f"{label}.mix.scenarios must be a non-empty unique array")
    if not _text(mix.get("capture_evidence")):
        errors.append(f"{label}.mix.capture_evidence is required")
    _review(errors, mix.get("listening"), f"{label}.mix.listening", native_required=True)
    if isinstance(mix.get("listening"), dict) and mix["listening"].get("backend") != backend:
        errors.append(f"{label}.mix.listening.backend must match mix.backend")

    accessibility = bundle.get("accessibility")
    if not isinstance(accessibility, dict):
        errors.append(f"{label}.accessibility must be an object")
        accessibility = {}
    if accessibility.get("captions") is not True:
        errors.append(f"{label}.accessibility.captions must be true")
    if not _strings(accessibility.get("caption_scenarios")):
        errors.append(f"{label}.accessibility.caption_scenarios must be a non-empty unique array")
    if not _strings(accessibility.get("audio_alternatives")):
        errors.append(f"{label}.accessibility.audio_alternatives must be a non-empty unique array")
    if not _text(accessibility.get("layout_evidence")):
        errors.append(f"{label}.accessibility.layout_evidence is required")
    _review(errors, accessibility.get("review"), f"{label}.accessibility.review")

    # A bundle is only a complete listening claim when every audio surface is
    # native and every review passed; otherwise the open boundary must remain
    # visible to release tooling and humans.
    statuses = [
        music.get("listening", {}).get("status") if isinstance(music.get("listening"), dict) else None,
        mix.get("listening", {}).get("status") if isinstance(mix.get("listening"), dict) else None,
        accessibility.get("review", {}).get("status") if isinstance(accessibility.get("review"), dict) else None,
    ]
    if bundle.get("claim") == "HUMAN_LISTENING_PASS":
        if backend != "native_output" or statuses != ["PASS", "PASS", "PASS"]:
            errors.append(f"{label}.claim HUMAN_LISTENING_PASS requires native audio and three PASS reviews")
    elif bundle.get("claim") == "AUTOMATED_ONLY":
        if not _text(bundle.get("boundary_note")):
            errors.append(f"{label}.boundary_note is required for AUTOMATED_ONLY")
    else:
        errors.append(f"{label}.claim must be HUMAN_LISTENING_PASS or AUTOMATED_ONLY")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    args = parser.parse_args(argv)
    errors = validate_bundle(json.loads(args.bundle.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_LISTENING_EVIDENCE_BUNDLE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_LISTENING_EVIDENCE_BUNDLE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
