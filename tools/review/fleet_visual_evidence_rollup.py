#!/usr/bin/env python3
"""Validate the bounded fleet visual-evidence handoff.

The rollup joins machine-captured views with the human-review items still
required for the five currently implemented craft. It is intentionally a
claim-boundary tool: it verifies coverage and provenance, but never turns a
capture into art sign-off or historical authentication.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "fleet_visual_evidence_rollup_v1"
EXPECTED_CRAFT = {
    "torrent_provisional",
    "arrow_provisional",
    "jovian_provisional",
    "zenith_b7_observed",
    "halyard_new_design",
}
MEDIUM_CRAFT = {"jovian_provisional", "halyard_new_design"}
REQUIRED_VIEWS = {"silhouette", "berth_or_approach", "cockpit_or_access"}
ALLOWED_CAPTURE_STATUSES = {"ready", "pending", "not_performed", "incomplete"}
ALLOWED_HUMAN_STATUSES = {"pending", "not_performed", "in_progress", "observed"}
FORBIDDEN_CLAIMS = {
    "approved",
    "approve",
    "pass",
    "passed",
    "complete",
    "completed",
    "released",
    "signed_off",
    "signed-off",
}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _forbidden_claim(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    normalized = value.strip().lower().replace(" ", "_")
    return normalized in FORBIDDEN_CLAIMS


def _validate_frame(frame: Any, prefix: str) -> list[str]:
    errors: list[str] = []
    if not isinstance(frame, dict):
        return [f"{prefix} must be an object"]
    for key in ("frame_id", "evidence_path", "description"):
        if not _text(frame.get(key)):
            errors.append(f"{prefix}.{key} must be non-empty text")
    resolution = frame.get("resolution")
    if not isinstance(resolution, list) or len(resolution) != 2 or any(not _positive_int(value) for value in resolution):
        errors.append(f"{prefix}.resolution must contain two positive integers")
    return errors


def _validate_craft(craft: Any, index: int, root: dict[str, Any]) -> list[str]:
    prefix = f"craft[{index}]"
    errors: list[str] = []
    if not isinstance(craft, dict):
        return [f"{prefix} must be an object"]
    craft_id = craft.get("craft_id")
    if not _text(craft_id):
        errors.append(f"{prefix}.craft_id must be non-empty text")
    if isinstance(craft_id, str) and craft_id not in EXPECTED_CRAFT:
        errors.append(f"{prefix}.craft_id is outside the current five-craft roster")
    evidence_status = craft.get("evidence_status")
    if evidence_status not in {"provisional", "new"}:
        errors.append(f"{prefix}.evidence_status must be provisional or new")
    references = craft.get("evidence_references")
    if not isinstance(references, list) or any(not _text(value) for value in references):
        errors.append(f"{prefix}.evidence_references must be an array of non-empty strings")
    elif evidence_status == "new" and references:
        errors.append(f"{prefix}.new craft cannot attach historical evidence references")
    elif evidence_status == "provisional" and not references:
        errors.append(f"{prefix}.provisional craft needs an evidence reference")

    capture = craft.get("capture")
    if not isinstance(capture, dict):
        errors.append(f"{prefix}.capture must be an object")
    else:
        status = capture.get("status")
        if status not in ALLOWED_CAPTURE_STATUSES:
            errors.append(f"{prefix}.capture.status is unsupported")
        views = capture.get("views")
        if not isinstance(views, dict):
            errors.append(f"{prefix}.capture.views must be an object")
        else:
            required_views = set(REQUIRED_VIEWS)
            if craft_id in MEDIUM_CRAFT:
                required_views.add("interior_route")
            missing = sorted(required_views - set(views))
            if missing:
                errors.append(f"{prefix}.capture.views missing: {', '.join(missing)}")
            for view_name, frames in views.items():
                if not isinstance(frames, list) or not frames:
                    errors.append(f"{prefix}.capture.views.{view_name} must contain one or more frames")
                    continue
                frame_ids: list[Any] = []
                for frame_index, frame in enumerate(frames):
                    errors.extend(_validate_frame(frame, f"{prefix}.capture.views.{view_name}[{frame_index}]"))
                    if isinstance(frame, dict):
                        frame_ids.append(frame.get("frame_id"))
                comparable_frame_ids = [frame_id for frame_id in frame_ids if isinstance(frame_id, str)]
                if len(comparable_frame_ids) != len(set(comparable_frame_ids)):
                    errors.append(f"{prefix}.capture.views.{view_name} contains duplicate frame IDs")

    human = craft.get("human_review")
    if not isinstance(human, dict):
        errors.append(f"{prefix}.human_review must be an object")
    else:
        if human.get("status") not in ALLOWED_HUMAN_STATUSES:
            errors.append(f"{prefix}.human_review.status is unsupported")
        for key in ("reviewer_required", "notes"):
            if not _text(human.get(key)):
                errors.append(f"{prefix}.human_review.{key} must be non-empty text")
        for key in ("decision", "outcome", "sign_off"):
            if _forbidden_claim(human.get(key)):
                errors.append(f"{prefix}.human_review.{key} cannot claim final approval")
    return errors


def validate_manifest(value: Any) -> list[str]:
    """Return blocking errors; an empty list means the handoff is well formed."""
    if not isinstance(value, dict):
        return ["manifest must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    if not _text(value.get("source_revision")):
        errors.append("source_revision must be non-empty text")
    if value.get("human_signoff_remains") is not True:
        errors.append("human_signoff_remains must remain true")
    remaining = value.get("remaining_gates")
    if not isinstance(remaining, list) or not remaining or any(not _text(item) for item in remaining):
        errors.append("remaining_gates must contain one or more non-empty strings")
    craft = value.get("craft")
    if not isinstance(craft, list) or not craft:
        return errors + ["craft must be a non-empty array"]
    ids = [item.get("craft_id") for item in craft if isinstance(item, dict)]
    comparable_ids = [craft_id for craft_id in ids if isinstance(craft_id, str)]
    if len(comparable_ids) != len(set(comparable_ids)):
        errors.append("craft IDs must be unique")
    if set(comparable_ids) != EXPECTED_CRAFT:
        errors.append("craft must exactly cover the current five-craft roster")
    for index, item in enumerate(craft):
        errors.extend(_validate_craft(item, index, value))

    # Scan only explicit decision-like fields, so a note may discuss an open
    # review without accidentally being interpreted as a release decision.
    def scan_decisions(item: Any, path: str = "manifest") -> None:
        if isinstance(item, dict):
            for key, child in item.items():
                if key in {"status", "decision", "outcome", "sign_off"} and _forbidden_claim(child):
                    errors.append(f"{path}.{key} cannot claim final approval")
                scan_decisions(child, f"{path}.{key}")
        elif isinstance(item, list):
            for item_index, child in enumerate(item):
                scan_decisions(child, f"{path}[{item_index}]")

    scan_decisions(value)
    return errors


def validate(path: Path) -> list[str]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    return validate_manifest(value)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest.resolve())
    if errors:
        print("FLEET_VISUAL_EVIDENCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("FLEET_VISUAL_EVIDENCE_READY: human visual sign-off remains external")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
