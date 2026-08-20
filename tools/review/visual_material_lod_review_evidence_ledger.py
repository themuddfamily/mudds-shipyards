#!/usr/bin/env python3
"""Validate the visual material/LOD review evidence handoff.

The ledger freezes the affected visual target families, near/mid/far distance
bands, and material-readability checks.  It is provenance only: this detached
validator cannot render a frame, measure native GPU behaviour, or grant art
direction sign-off.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SCHEMA = "visual_material_lod_review_evidence_v1"
HUMAN_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
REVIEW_RESULTS = {"pending", "clear", "issue", "not_assessed"}
MATERIAL_STATUSES = {"planned", "authored", "pending"}
TARGETS = (
    "station",
    "fleet",
    "planetary_surface",
    "cockpit",
    "effects",
)
TARGET_ROLES = {
    "station": "station structure and signage",
    "fleet": "craft silhouette and hull surfaces",
    "planetary_surface": "terrain, water, and shoreline surfaces",
    "cockpit": "cockpit controls and instrument materials",
    "effects": "emissive, particle, and transition effects",
}
TIERS = ("near", "mid", "far")
TIER_BOUNDS = {"near": (0.0, 30.0), "mid": (30.0, 120.0), "far": (120.0, 500.0)}
MATERIAL_ASPECTS = (
    "albedo_palette",
    "roughness_metalness",
    "normal_detail",
    "emissive_readability",
    "material_separation",
    "texture_sampling",
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
        path, digest = reference.get("path"), reference.get("sha256")
        if isinstance(path, str) and isinstance(digest, str):
            identity = (path, digest)
            if identity in seen:
                errors.append(f"{label} duplicates an earlier reference")
            seen.add(identity)


def _validate_materials(value: Any) -> list[str]:
    errors: list[str] = []
    if not isinstance(value, list) or len(value) != len(TARGETS):
        return ["materials must contain exactly five visual target declarations"]
    ids: list[str] = []
    for index, material in enumerate(value):
        prefix = f"materials[{index}]"
        if not isinstance(material, dict):
            errors.append(f"{prefix} must be an object")
            continue
        target = material.get("target_id")
        if target not in TARGETS:
            errors.append(f"{prefix}.target_id must be one of the five frozen visual targets")
        elif target in ids:
            errors.append(f"{prefix}.target_id duplicates an earlier target")
        else:
            ids.append(target)
        if isinstance(target, str) and target in TARGET_ROLES and material.get("role") != TARGET_ROLES[target]:
            errors.append(f"{prefix}.role must match the target's frozen visual role")
        for key in ("material_family", "lod_source"):
            if not _text(material.get(key)):
                errors.append(f"{prefix}.{key} must be non-empty text")
        if not isinstance(material.get("status"), str) or material.get("status") not in MATERIAL_STATUSES:
            errors.append(f"{prefix}.status must remain planned, authored, or pending")
        if material.get("lod_tiers") != list(TIERS):
            errors.append(f"{prefix}.lod_tiers must exactly match near, mid, far")
    if tuple(ids) != TARGETS:
        errors.append("materials must exactly cover the five frozen visual targets in order")
    return errors


def _validate_reviews(value: Any) -> list[str]:
    errors: list[str] = []
    expected = {(target, tier) for target in TARGETS for tier in TIERS}
    if not isinstance(value, list):
        return ["reviews must contain exactly one row for every target/tier pair"]
    if len(value) != len(expected):
        errors.append("reviews must contain exactly one row for every target/tier pair")
    seen: set[tuple[str, str]] = set()
    evidence_seen: set[tuple[str, str]] = set()
    for index, review in enumerate(value):
        prefix = f"reviews[{index}]"
        if not isinstance(review, dict):
            errors.append(f"{prefix} must be an object")
            continue
        target, tier = review.get("target_id"), review.get("tier")
        if target not in TARGETS:
            errors.append(f"{prefix}.target_id must be one of the five frozen visual targets")
        if tier not in TIERS:
            errors.append(f"{prefix}.tier must be near, mid, or far")
        key = (
            target if isinstance(target, str) else repr(target),
            tier if isinstance(tier, str) else repr(tier),
        )
        if key in seen:
            errors.append(f"{prefix} duplicates an earlier target/tier pair")
        seen.add(key)
        bounds = TIER_BOUNDS.get(tier) if isinstance(tier, str) else None
        distance = review.get("distance_m")
        if not isinstance(distance, dict):
            errors.append(f"{prefix}.distance_m must be an object")
        elif bounds is not None:
            if distance.get("min") != bounds[0] or distance.get("max") != bounds[1]:
                errors.append(f"{prefix}.distance_m must match the frozen {tier} distance band")
        if not _text(review.get("camera")):
            errors.append(f"{prefix}.camera must be non-empty text")
        result = review.get("result")
        if not isinstance(result, str) or result not in REVIEW_RESULTS:
            errors.append(f"{prefix}.result must be pending, clear, issue, or not_assessed")
        aspects = review.get("material_aspects")
        if not isinstance(aspects, dict) or set(aspects) != set(MATERIAL_ASPECTS):
            errors.append(f"{prefix}.material_aspects must exactly cover the frozen material checks")
        else:
            for aspect in MATERIAL_ASPECTS:
                status = aspects[aspect]
                if not isinstance(status, str) or status not in REVIEW_RESULTS:
                    errors.append(f"{prefix}.material_aspects.{aspect} has an invalid review result")
        evidence = review.get("evidence")
        allow_none = isinstance(result, str) and result in {"pending", "not_assessed"}
        _references(evidence, f"{prefix}.evidence", errors, allow_none=allow_none)
        if isinstance(evidence, list):
            for reference in evidence:
                if not isinstance(reference, dict):
                    continue
                path, digest = reference.get("path"), reference.get("sha256")
                if isinstance(path, str) and isinstance(digest, str) and _sha(digest):
                    identity = (path, digest)
                    if identity in evidence_seen:
                        errors.append(f"{prefix}.evidence duplicates an earlier ledger reference")
                    evidence_seen.add(identity)
        if not _text(review.get("notes")):
            errors.append(f"{prefix}.notes must be non-empty text")
    if seen != expected:
        errors.append("reviews must exactly cover every target/tier pair")
    return errors


def validate_ledger(value: Any) -> list[str]:
    """Return blocking errors; empty means ready for the still-open art gate."""
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
    if value.get("native_render_performed") is not False:
        errors.append("native_render_performed must remain false")
    if value.get("detached_contract_tests_only") is not True:
        errors.append("detached_contract_tests_only must be true")
    errors.extend(_validate_materials(value.get("materials")))
    errors.extend(_validate_reviews(value.get("reviews")))
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
        print("VISUAL_MATERIAL_LOD_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("VISUAL_MATERIAL_LOD_READY: native render and human art review remain open")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
