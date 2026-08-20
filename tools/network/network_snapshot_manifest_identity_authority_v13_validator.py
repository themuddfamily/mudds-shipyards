#!/usr/bin/env python3
"""Validate v13 authority-scoped snapshot manifest identity evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 13
EVIDENCE_SCOPE = "network_snapshot_manifest_identity_authority_v13"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _manifest_identity_digest(manifest: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{manifest.get('manifest_id')}|{manifest.get('sequence')}|{manifest.get('digest')}".encode("utf-8")).hexdigest()


def _member_identity_digest(manifest: dict[str, Any], member: dict[str, Any]) -> str:
    return hashlib.sha256(f"{manifest.get('identity_digest')}|{member.get('member_id')}|{member.get('member_digest')}".encode("utf-8")).hexdigest()


def validate_identity(report: Any, label: str = "identity") -> list[str]:
    """Return identity, membership, count, and no-mutation errors."""

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

    manifest = report.get("manifest")
    if not isinstance(manifest, dict):
        errors.append(f"{label}.manifest must be an object")
        manifest = {}
    if manifest.get("authority") != AUTHORITY:
        errors.append(f"{label}.manifest.authority must be {AUTHORITY}")
    if not isinstance(manifest.get("manifest_id"), str) or not manifest.get("manifest_id"):
        errors.append(f"{label}.manifest.manifest_id must be non-empty")
    if not _sequence(manifest.get("sequence")):
        errors.append(f"{label}.manifest.sequence must be non-negative")
    if not _digest(manifest.get("digest")):
        errors.append(f"{label}.manifest.digest must be lowercase SHA-256")
    identity_digest = manifest.get("identity_digest")
    if not _digest(identity_digest):
        errors.append(f"{label}.manifest.identity_digest must be lowercase SHA-256")
    elif identity_digest != _manifest_identity_digest(manifest):
        errors.append(f"{label}.manifest.identity_digest must anchor manifest identity")

    members = report.get("members")
    if not isinstance(members, list):
        errors.append(f"{label}.members must be an array")
        members = []
    member_ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, member in enumerate(members):
        prefix = f"{label}.members[{index}]"
        if not isinstance(member, dict):
            errors.append(f"{prefix} must be an object")
            continue
        member_id = member.get("member_id")
        if not isinstance(member_id, str) or not member_id:
            errors.append(f"{prefix}.member_id must be non-empty")
        elif member_id in member_ids:
            errors.append(f"{prefix}.member_id must be unique")
        else:
            member_ids.add(member_id)
        if member.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if member.get("manifest_id") != manifest.get("manifest_id"):
            errors.append(f"{prefix}.manifest_id must match manifest identity")
        if member.get("identity_digest") != identity_digest:
            errors.append(f"{prefix}.identity_digest must match manifest identity")
        if not _digest(member.get("member_digest")):
            errors.append(f"{prefix}.member_digest must be lowercase SHA-256")
        member_identity = member.get("member_identity_digest")
        if not _digest(member_identity):
            errors.append(f"{prefix}.member_identity_digest must be lowercase SHA-256")
        elif member_identity != _member_identity_digest(manifest, member):
            errors.append(f"{prefix}.member_identity_digest must anchor member identity")
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
        expected = {"members": len(members), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match manifest members")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_identity_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_identity(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identity", type=Path)
    args = parser.parse_args()
    errors = validate_identity_file(args.identity)
    if errors:
        print("NETWORK_SNAPSHOT_MANIFEST_IDENTITY_AUTHORITY_V13_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_MANIFEST_IDENTITY_AUTHORITY_V13_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
