"""Validate the bounded station visual hierarchy and material identity review.

This catalog is an art-direction brief, not a claim about recovered source
material.  It freezes the intended navigation/readability ordering and the
colour-safe channels that a future human art review must inspect.  It does
not inspect renderer output, approve assets, or promote any palette to
historical evidence.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
DOCUMENT_ID = "station_visual_hierarchy"
MODULE_KINDS = frozenset({"station", "fleet", "nearby_sector", "ui"})
REVIEW_STATES = frozenset({"pending_art_review", "reviewed"})
REQUIRED_REVIEW_AXES = frozenset(
    {
        "navigation",
        "readability",
        "coherent_scale",
        "material_hierarchy",
        "colour_safe_cues",
        "composition",
    }
)
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")


def _read_json(path: str | Path) -> Any:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _text_list(value: Any) -> list[str] | None:
    if not isinstance(value, list) or not value or not all(_text(item) for item in value):
        return None
    return [str(item) for item in value]


def validate_manifest(path: str | Path) -> list[str]:
    """Return fail-closed errors for a visual hierarchy manifest."""

    try:
        document = _read_json(path)
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest cannot be read as JSON: {exc}"]
    if not isinstance(document, dict):
        return ["manifest root must be an object"]

    errors: list[str] = []
    if document.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if document.get("document_id") != DOCUMENT_ID:
        errors.append(f"document_id must be {DOCUMENT_ID}")
    if document.get("evidence_boundary") != "modern_interpretation_only":
        errors.append("evidence_boundary must remain modern_interpretation_only")
    if document.get("historical_authentication") != "none":
        errors.append("historical_authentication must remain none")

    review = document.get("review")
    if not isinstance(review, dict):
        errors.append("review must be an object")
        review = {}
    if review.get("status") != "pending_art_review":
        errors.append("review status must remain pending_art_review")
    axes = review.get("required_axes")
    if not isinstance(axes, list) or set(axes) != REQUIRED_REVIEW_AXES:
        errors.append("review required_axes must cover the six declared art-direction axes")
    if review.get("native_playtest_required") is not True:
        errors.append("native_playtest_required must be true")
    if review.get("renderer_approval") is not False:
        errors.append("renderer_approval must remain false until human review")

    modules = document.get("modules")
    if not isinstance(modules, list) or not modules:
        errors.append("modules must be a non-empty array")
        modules = []
    seen_ids: set[str] = set()
    seen_priorities: set[int] = set()
    seen_primaries: set[str] = set()
    for index, module in enumerate(modules):
        prefix = f"module {index + 1}"
        if not isinstance(module, dict):
            errors.append(f"{prefix} must be an object")
            continue
        module_id = module.get("id")
        if not _text(module_id):
            errors.append(f"{prefix} must have a stable id")
            label = prefix
        else:
            label = f"{prefix} {module_id}"
            if str(module_id) in seen_ids:
                errors.append(f"{label} duplicates id")
            seen_ids.add(str(module_id))
        if module.get("kind") not in MODULE_KINDS:
            errors.append(f"{label} has an invalid kind")
        if module.get("identity_status") != "modern_interpretation":
            errors.append(f"{label} must be tagged modern_interpretation")
        if module.get("review_status") not in REVIEW_STATES:
            errors.append(f"{label} has an invalid review_status")
        elif module.get("review_status") != "pending_art_review":
            errors.append(f"{label} must remain pending_art_review")

        priority = module.get("navigation_priority")
        if not isinstance(priority, int) or priority < 1 or priority > len(modules):
            errors.append(f"{label} navigation_priority must be in 1..{len(modules)}")
        elif priority in seen_priorities:
            errors.append(f"{label} duplicates navigation_priority {priority}")
        else:
            seen_priorities.add(priority)

        palette = module.get("palette")
        if not isinstance(palette, dict):
            errors.append(f"{label} palette must be an object")
            palette = {}
        colors = palette.get("colors")
        if not isinstance(colors, dict):
            errors.append(f"{label} palette colors must be an object")
            colors = {}
        for role in ("primary", "secondary", "accent", "warning"):
            color = colors.get(role)
            if not isinstance(color, str) or not HEX.fullmatch(color):
                errors.append(f"{label} palette {role} must be a six-digit hex colour")
        primary = colors.get("primary")
        if isinstance(primary, str):
            normalized = primary.casefold()
            if normalized in seen_primaries:
                errors.append(f"{label} duplicates another module primary colour")
            seen_primaries.add(normalized)
        for field in ("material_families", "silhouette_cues", "shape_cues"):
            if _text_list(module.get(field)) is None:
                errors.append(f"{label} {field} must be a non-empty text array")
        if module.get("colour_safe_shape_channel") is not True:
            errors.append(f"{label} must provide a colour-safe shape channel")
        if module.get("decorative_density") not in {"deferred", "bounded"}:
            errors.append(f"{label} decorative_density must be deferred or bounded")
        if not _text(module.get("review_note")):
            errors.append(f"{label} must state its pending review boundary")

    if len(seen_priorities) != len(modules):
        errors.append("navigation priorities must form one complete unique ordering")
    return errors


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate_manifest(args.manifest)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("STATION_VISUAL_HIERARCHY_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
