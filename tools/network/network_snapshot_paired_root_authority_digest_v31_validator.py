#!/usr/bin/env python3
"""Validate v31 paired root/authority digest evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 31
EVIDENCE_SCOPE = "network_snapshot_paired_root_authority_digest_v31"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _state(value: Any) -> bool:
    return isinstance(value, dict) and _sequence(value.get("sequence")) and _digest(value.get("digest"))


def _authority_digest(root: dict[str, Any]) -> str:
    left = root.get("left", {})
    right = root.get("right", {})
    payload = f"{AUTHORITY}|{root.get('pair_id')}|{left.get('sequence')}|{left.get('digest')}|{right.get('sequence')}|{right.get('digest')}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def validate_digest(report: Any, label: str = "digest") -> list[str]:
    """Return paired root authority digest, references, counts, and mutation errors."""

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

    root = report.get("root_pair")
    if not isinstance(root, dict):
        errors.append(f"{label}.root_pair must be an object")
        root = {}
    if root.get("authority") != AUTHORITY:
        errors.append(f"{label}.root_pair.authority must be {AUTHORITY}")
    if not isinstance(root.get("pair_id"), str) or not root.get("pair_id"):
        errors.append(f"{label}.root_pair.pair_id must be non-empty")
    left = root.get("left")
    right = root.get("right")
    for name, state in (("left", left), ("right", right)):
        if not _state(state):
            errors.append(f"{label}.root_pair.{name} must contain sequence and lowercase SHA-256 digest")
    if _state(left) and _state(right) and left != right:
        errors.append(f"{label}.root_pair.right must equal left")
    authority_digest = root.get("authority_digest")
    if not _digest(authority_digest):
        errors.append(f"{label}.root_pair.authority_digest must be lowercase SHA-256")
    elif authority_digest != _authority_digest(root):
        errors.append(f"{label}.root_pair.authority_digest must bind paired root")

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
        if member.get("authority_digest") != authority_digest:
            errors.append(f"{prefix}.authority_digest must match root pair")
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
                errors.append(f"{label}.counts.{key} must match authority members")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_digest_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_digest(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("digest", type=Path)
    args = parser.parse_args()
    errors = validate_digest_file(args.digest)
    if errors:
        print("NETWORK_SNAPSHOT_PAIRED_ROOT_AUTHORITY_DIGEST_V31_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_PAIRED_ROOT_AUTHORITY_DIGEST_V31_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
