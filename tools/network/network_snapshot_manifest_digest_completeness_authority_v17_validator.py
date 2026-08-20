#!/usr/bin/env python3
"""Validate v17 authority-scoped snapshot manifest digest completeness."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 17
EVIDENCE_SCOPE = "network_snapshot_manifest_digest_completeness_authority_v17"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _authority_digest(manifest: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{manifest.get('sequence')}|{manifest.get('root_digest')}".encode("utf-8")).hexdigest()


def _completeness_digest(expected_keys: list[str]) -> str:
    return hashlib.sha256("\n".join(expected_keys).encode("utf-8")).hexdigest()


def _entries_digest(entries: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{entry.get('order')}|{entry.get('key')}|{entry.get('digest')}" for entry in entries).encode("utf-8")).hexdigest()


def validate_completeness(report: Any, label: str = "completeness") -> list[str]:
    """Return authority, key coverage, digest, count, and no-mutation errors."""

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
    if not _sequence(manifest.get("sequence")):
        errors.append(f"{label}.manifest.sequence must be non-negative")
    if not _digest(manifest.get("root_digest")):
        errors.append(f"{label}.manifest.root_digest must be lowercase SHA-256")
    if not _digest(manifest.get("authority_digest")):
        errors.append(f"{label}.manifest.authority_digest must be lowercase SHA-256")
    elif manifest["authority_digest"] != _authority_digest(manifest):
        errors.append(f"{label}.manifest.authority_digest must anchor authority manifest")

    expected_keys = report.get("expected_keys")
    if not isinstance(expected_keys, list) or not expected_keys or not all(isinstance(key, str) and key for key in expected_keys):
        errors.append(f"{label}.expected_keys must be a non-empty string array")
        expected_keys = []
    if len(set(expected_keys)) != len(expected_keys):
        errors.append(f"{label}.expected_keys must be unique")
    completeness_digest = report.get("completeness_digest")
    if not _digest(completeness_digest):
        errors.append(f"{label}.completeness_digest must be lowercase SHA-256")
    elif completeness_digest != _completeness_digest(expected_keys):
        errors.append(f"{label}.completeness_digest must match expected keys")

    entries = report.get("entries")
    if not isinstance(entries, list):
        errors.append(f"{label}.entries must be an array")
        entries = []
    entry_keys: list[str] = []
    reconciled_count = 0
    mutation_count = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if entry.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        entry_key = entry.get("key")
        if not isinstance(entry_key, str) or not entry_key:
            errors.append(f"{prefix}.key must be non-empty")
        entry_keys.append(entry_key if isinstance(entry_key, str) else "")
        if entry.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if entry.get("authority_digest") != manifest.get("authority_digest"):
            errors.append(f"{prefix}.authority_digest must match manifest authority")
        if entry.get("sequence") != manifest.get("sequence"):
            errors.append(f"{prefix}.sequence must match manifest sequence")
        if not _digest(entry.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if entry.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if entry.get("mutation_fields") != [] or entry.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
    if entry_keys != expected_keys:
        errors.append(f"{label}.entries must exactly cover expected_keys in order")
    entries_digest = report.get("entries_digest")
    if not _digest(entries_digest):
        errors.append(f"{label}.entries_digest must be lowercase SHA-256")
    elif entries_digest != _entries_digest(entries):
        errors.append(f"{label}.entries_digest must match ordered entries")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"expected": len(expected_keys), "entries": len(entries), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match completeness evidence")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_completeness_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_completeness(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("completeness", type=Path)
    args = parser.parse_args()
    errors = validate_completeness_file(args.completeness)
    if errors:
        print("NETWORK_SNAPSHOT_MANIFEST_DIGEST_COMPLETENESS_AUTHORITY_V17_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_MANIFEST_DIGEST_COMPLETENESS_AUTHORITY_V17_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
