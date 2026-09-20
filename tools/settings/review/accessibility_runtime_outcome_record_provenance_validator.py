#!/usr/bin/env python3
"""Validate v261-v1029 accessibility runtime outcome-record provenance evidence.

This replaces 769 per-version modules. All but a handful were twenty-line
wrappers that renamed the schema string and delegated to one shared
implementation, so the contract is a single set of checks parameterised by the
version a document declares: the provenance record names its schema and source
schema, keeps every authority flag false, leaves the human-review gate open and
the native-render gate not run, pins the outcome policy and binding verbatim,
and hashes any attached evidence with SHA-256.

Like `tools/audio/audio_cleanup_evidence_state_validator.py`, this implements
the family's contract across its historical version range rather than
reproducing each retired module. It validates detached evidence documents only:
a valid document asserts that accessibility review has *not* been performed, so
this tool can never be read as a review, a native run, or a human sign-off.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

SUPPORTED_VERSIONS = range(261, 1030)
SOURCE_SCHEMA = "runtime_accessibility_outcome_record_policy_v1"
SOURCE_ID = "runtime-accessibility-outcome-record-policy"
CONTRACT_ID = "runtime-accessibility-presentation"
SOURCE_OF_TRUTH = "runtime_accessibility_outcome_record_policy"
OPEN_REVIEW_STATUSES = {"pending", "not_performed", "in_progress", "failed"}
RECORD_STATUSES = {"planned", "pending", "not_performed"}
EVIDENCE_KINDS = {"log", "image", "report", "video"}
SHA256 = re.compile(r"^[0-9a-f]{64}$")

OUTCOME_POLICY = {
    "sequence": ["declare_scope", "list_outcomes", "mark_gates", "defer_outcome"],
    "artifact_types": ["validator", "test", "manifest", "evidence"],
    "outcome_states": ["prepared", "pending_review", "deferred"],
    "outcome_fields": ["accessibility", "captions", "audio", "bindings", "camera"],
    "missing_artifact": "mark_incomplete_without_claim",
    "secret_logging": "never",
}
BINDING = {
    "source_schema": SOURCE_SCHEMA,
    "source_id": SOURCE_ID,
    "contract_id": CONTRACT_ID,
    "policy_mode": "exact",
    "apply_rule": "provenance_outcome_only",
    "human_gate": "open",
    "native_policy": "not_run",
}
AUTHORITY = {
    "presentation_only": True,
    "outcome_record_authority": False,
    "settings_read_authority": False,
    "settings_write_authority": False,
    "audio_authority": False,
    "caption_queue_authority": False,
    "gameplay_authority": False,
    "network_authority": False,
}
_FALSE_FLAGS = (
    "human_review_performed",
    "native_render_performed",
    "policy_verified",
    "runtime_claimed",
    "outcome_written",
    "outcome_confirmed",
)


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def schema_name(version: int) -> str:
    return f"accessibility_runtime_outcome_record_provenance_v{version}_evidence_v1"


def document_version(value: Any) -> int | None:
    """The version a document declares as `schema_version`, e.g. "v306" -> 306."""
    if not isinstance(value, dict):
        return None
    declared = value.get("schema_version")
    if isinstance(declared, str) and declared.startswith("v") and declared[1:].isdigit():
        return int(declared[1:])
    return None


def validate_runtime_outcome_record_provenance(
    value: Any,
    *,
    schema_version: int | None = None,
) -> list[str]:
    """Return blocking errors for one provenance record.

    `schema_version` pins the expected version; by default the record's own
    declared version is used and must fall inside the supported range.
    """
    if not isinstance(value, dict):
        return ["record must be an object"]
    version = schema_version if schema_version is not None else document_version(value)
    if version is None or version not in SUPPORTED_VERSIONS:
        return ["schema_version must be v261 through v1029"]

    errors: list[str] = []
    if value.get("schema") != schema_name(version):
        errors.append("schema")
    if value.get("source_schema") != SOURCE_SCHEMA:
        errors.append("source_schema")
    if value.get("schema_version") != f"v{version}":
        errors.append("schema_version")
    for key in ("source_revision", "reviewer_required", "open_gate_reason"):
        if not _text(value.get(key)):
            errors.append(key)
    if value.get("human_review_status") not in OPEN_REVIEW_STATUSES:
        errors.append("human_review_status")
    if value.get("native_render_status") != "not_run":
        errors.append("native_render_status")
    for key in _FALSE_FLAGS:
        if value.get(key) is not False:
            errors.append(key)
    if value.get("outcome_policy") != OUTCOME_POLICY:
        errors.append("outcome_policy")
    if value.get("binding") != BINDING:
        errors.append("binding")
    if value.get("authority") != AUTHORITY:
        errors.append("authority")
    for key, expected in AUTHORITY.items():
        if value.get(key) is not expected:
            errors.append(key)
    if (
        value.get("source_id") != SOURCE_ID
        or value.get("contract_id") != CONTRACT_ID
        or value.get("provenance_source_of_truth") != SOURCE_OF_TRUTH
    ):
        errors.append("provenance")
    if value.get("status") not in RECORD_STATUSES:
        errors.append("status")

    evidence = value.get("evidence")
    if evidence is not None:
        if not isinstance(evidence, list) or not evidence:
            errors.append("evidence")
        else:
            for item in evidence:
                if (
                    not isinstance(item, dict)
                    or item.get("kind") not in EVIDENCE_KINDS
                    or not _text(item.get("path"))
                    or not isinstance(item.get("sha256"), str)
                    or not SHA256.fullmatch(item["sha256"])
                ):
                    errors.append("evidence item")
    return errors


def validate(path: str | Path, *, schema_version: int | None = None) -> list[str]:
    try:
        return validate_runtime_outcome_record_provenance(
            json.loads(Path(path).read_text(encoding="utf-8")),
            schema_version=schema_version,
        )
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unreadable: {exc}"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("provenance", type=Path)
    parser.add_argument("--schema-version", type=int, default=None)
    args = parser.parse_args(argv)
    errors = validate(args.provenance, schema_version=args.schema_version)
    if errors:
        print("ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(
        "ACCESSIBILITY_RUNTIME_OUTCOME_RECORD_PROVENANCE_READY: "
        "review and native gates remain open"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
