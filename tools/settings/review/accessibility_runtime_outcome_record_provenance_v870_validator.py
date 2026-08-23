"""Validate v870 accessibility runtime outcome provenance."""
from __future__ import annotations

import json
from pathlib import Path

from tools.settings.review import accessibility_runtime_outcome_record_provenance_v306_validator as base

SCHEMA = "accessibility_runtime_outcome_record_provenance_v870_evidence_v1"


def validate_runtime_outcome_record_provenance(value):
    if not isinstance(value, dict):
        return ["record must be an object"]
    candidate = dict(value)
    candidate["schema"] = base.SCHEMA
    candidate["schema_version"] = "v306"
    errors = base.validate_runtime_outcome_record_provenance(candidate)
    if value.get("schema") != SCHEMA:
        errors.append("schema")
    if value.get("schema_version") != "v870":
        errors.append("schema_version")
    return errors


def validate(path):
    try:
        return validate_runtime_outcome_record_provenance(
            json.loads(Path(path).read_text(encoding="utf-8"))
        )
    except (OSError, json.JSONDecodeError) as exc:
        return [str(exc)]
