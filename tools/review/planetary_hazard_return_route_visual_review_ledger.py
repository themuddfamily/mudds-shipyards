#!/usr/bin/env python3
"""Validate visual review evidence for authored hazard return routes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

SCHEMA = "planetary_hazard_return_route_visual_review_v1"
OPEN = {"pending", "not_performed"}
STAGES = ("hazard", "safe_anchor", "return_anchor")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate_ledger(value: Any, label: str = "ledger") -> list[str]:
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if value.get("schema") != SCHEMA:
        errors.append(f"{label}.schema must be {SCHEMA}")
    for key in ("world_id", "route_id", "source_revision"):
        if not _text(value.get(key)):
            errors.append(f"{label}.{key} is required")
    stages = value.get("stages")
    if not isinstance(stages, list) or len(stages) != len(STAGES):
        errors.append(f"{label}.stages must contain hazard, safe_anchor, and return_anchor")
        stages = stages if isinstance(stages, list) else []
    seen: set[str] = set()
    for index, stage in enumerate(stages):
        prefix = f"{label}.stages[{index}]"
        if not isinstance(stage, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = stage.get("id")
        if ident not in STAGES or ident in seen:
            errors.append(f"{prefix}.id must be unique and ordered")
        seen.add(ident)
        if ident != STAGES[index] if index < len(STAGES) else True:
            errors.append(f"{prefix}.id is out of order")
        if not _text(stage.get("capture_id")) or not _text(stage.get("visual_question")):
            errors.append(f"{prefix} requires capture_id and visual_question")
        if stage.get("review_status") not in OPEN:
            errors.append(f"{prefix}.review_status must remain open")
    recovery = value.get("recovery")
    if not isinstance(recovery, dict):
        errors.append(f"{label}.recovery must be an object")
    else:
        for key in ("recovery_id", "safe_anchor_id", "return_anchor_id"):
            if not _text(recovery.get(key)):
                errors.append(f"{label}.recovery.{key} is required")
        if recovery.get("runtime_resolution") != "external_recovery_authority":
            errors.append(f"{label}.recovery.runtime_resolution must remain external")
        if recovery.get("review_status") not in OPEN:
            errors.append(f"{label}.recovery.review_status must remain open")
    for key in ("native_render", "human_review"):
        gate = value.get(key)
        if not isinstance(gate, dict) or gate.get("status") not in OPEN:
            errors.append(f"{label}.{key}.status must remain open")
    exclusions = value.get("claims_excluded")
    if not isinstance(exclusions, list) or not {"recovery_runtime", "native_render", "human_review"}.issubset(set(exclusions)):
        errors.append(f"{label}.claims_excluded must preserve all open gates")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args(argv)
    errors = validate_ledger(json.loads(args.ledger.read_text(encoding="utf-8")))
    if errors:
        print("PLANETARY_HAZARD_RETURN_REVIEW_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("PLANETARY_HAZARD_RETURN_REVIEW_VALID_OPEN")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
