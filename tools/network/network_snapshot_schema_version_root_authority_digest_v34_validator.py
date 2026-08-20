#!/usr/bin/env python3
"""Validate v34 schema/version root authority digest evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 34
EVIDENCE_SCOPE = "network_snapshot_schema_version_root_authority_digest_v34"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SCHEMA_NAME = "snapshot"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _authority_digest(root: dict[str, Any], schema: dict[str, Any]) -> str:
    payload = f"{AUTHORITY}|{schema.get('name')}|{schema.get('version')}|{root.get('sequence')}|{root.get('digest')}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_schema(report: Any, label: str = "schema") -> list[str]:
    """Return schema, root digest, member version, count, and mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
        ("authority", AUTHORITY),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    schema = report.get("snapshot_schema")
    if not isinstance(schema, dict):
        errors.append(f"{label}.snapshot_schema must be an object")
        schema = {}
    if schema.get("name") != SCHEMA_NAME:
        errors.append(f"{label}.snapshot_schema.name must be {SCHEMA_NAME}")
    if not _positive_int(schema.get("version")):
        errors.append(f"{label}.snapshot_schema.version must be positive")

    root = report.get("root")
    if not isinstance(root, dict):
        errors.append(f"{label}.root must be an object")
        root = {}
    if root.get("authority") != AUTHORITY:
        errors.append(f"{label}.root.authority must be {AUTHORITY}")
    if root.get("schema_version") != schema.get("version"):
        errors.append(f"{label}.root.schema_version must match snapshot schema")
    if not _sequence(root.get("sequence")):
        errors.append(f"{label}.root.sequence must be non-negative")
    if not _digest(root.get("digest")):
        errors.append(f"{label}.root.digest must be lowercase SHA-256")
    authority_digest = root.get("authority_digest")
    if not _digest(authority_digest):
        errors.append(f"{label}.root.authority_digest must be lowercase SHA-256")
    elif authority_digest != _authority_digest(root, schema):
        errors.append(f"{label}.root.authority_digest must bind schema version")

    members = report.get("members")
    if not isinstance(members, list):
        errors.append(f"{label}.members must be an array")
        members = []
    ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, member in enumerate(members):
        prefix = f"{label}.members[{index}]"
        if not isinstance(member, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if member.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        member_id = member.get("member_id")
        if not isinstance(member_id, str) or not member_id:
            errors.append(f"{prefix}.member_id must be non-empty")
        elif member_id in ids:
            errors.append(f"{prefix}.member_id must be unique")
        else:
            ids.add(member_id)
        if member.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if member.get("schema_version") != schema.get("version"):
            errors.append(f"{prefix}.schema_version must match snapshot schema")
        if member.get("authority_digest") != authority_digest:
            errors.append(f"{prefix}.authority_digest must match root")
        if not _digest(member.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if member.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if member.get("mutation_fields") != [] or member.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"members": len(members), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match schema members")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_schema_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_schema(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema", type=Path)
    args = parser.parse_args()
    errors = validate_schema_file(args.schema)
    if errors:
        print("NETWORK_SNAPSHOT_SCHEMA_VERSION_ROOT_AUTHORITY_DIGEST_V34_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_SCHEMA_VERSION_ROOT_AUTHORITY_DIGEST_V34_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
