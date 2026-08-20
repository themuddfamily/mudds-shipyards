#!/usr/bin/env python3
"""Validate v18 expected/observed snapshot completeness authority evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 18
EVIDENCE_SCOPE = "network_snapshot_completeness_authority_digest_v18"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _authority_digest(root: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{root.get('sequence')}|{root.get('root_digest')}".encode("utf-8")).hexdigest()


def _key_set_digest(keys: list[str]) -> str:
    return hashlib.sha256("\n".join(sorted(keys)).encode("utf-8")).hexdigest()


def _observed_digest(entries: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{entry.get('position')}|{entry.get('key')}|{entry.get('digest')}" for entry in entries).encode("utf-8")).hexdigest()


def validate_completeness(report: Any, label: str = "completeness") -> list[str]:
    """Return expected/observed coverage, digest, count, and mutation errors."""

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

    root = report.get("root")
    if not isinstance(root, dict):
        errors.append(f"{label}.root must be an object")
        root = {}
    if root.get("authority") != AUTHORITY:
        errors.append(f"{label}.root.authority must be {AUTHORITY}")
    if not _sequence(root.get("sequence")):
        errors.append(f"{label}.root.sequence must be non-negative")
    if not _digest(root.get("root_digest")):
        errors.append(f"{label}.root.root_digest must be lowercase SHA-256")
    if not _digest(root.get("authority_digest")):
        errors.append(f"{label}.root.authority_digest must be lowercase SHA-256")
    elif root["authority_digest"] != _authority_digest(root):
        errors.append(f"{label}.root.authority_digest must anchor root")

    expected = report.get("expected")
    if not isinstance(expected, dict):
        errors.append(f"{label}.expected must be an object")
        expected = {}
    expected_keys = expected.get("keys")
    if not isinstance(expected_keys, list) or not expected_keys or not all(isinstance(key, str) and key for key in expected_keys):
        errors.append(f"{label}.expected.keys must be a non-empty string array")
        expected_keys = []
    if len(set(expected_keys)) != len(expected_keys):
        errors.append(f"{label}.expected.keys must be unique")
    if expected.get("count") != len(expected_keys):
        errors.append(f"{label}.expected.count must match expected keys")
    if not _digest(expected.get("keys_digest")):
        errors.append(f"{label}.expected.keys_digest must be lowercase SHA-256")
    elif expected["keys_digest"] != _key_set_digest(expected_keys):
        errors.append(f"{label}.expected.keys_digest must match expected key set")

    observed = report.get("observed")
    if not isinstance(observed, list):
        errors.append(f"{label}.observed must be an array")
        observed = []
    observed_keys: list[str] = []
    complete_count = 0
    mutation_count = 0
    for index, entry in enumerate(observed):
        prefix = f"{label}.observed[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if entry.get("position") != index + 1:
            errors.append(f"{prefix}.position must be {index + 1}")
        key = entry.get("key")
        if not isinstance(key, str) or not key:
            errors.append(f"{prefix}.key must be non-empty")
        observed_keys.append(key if isinstance(key, str) else "")
        if entry.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if entry.get("authority_digest") != root.get("authority_digest"):
            errors.append(f"{prefix}.authority_digest must match root")
        if entry.get("sequence") != root.get("sequence"):
            errors.append(f"{prefix}.sequence must match root")
        if not _digest(entry.get("digest")):
            errors.append(f"{prefix}.digest must be lowercase SHA-256")
        if entry.get("complete") is not True:
            errors.append(f"{prefix}.complete must be true")
        else:
            complete_count += 1
        if entry.get("mutation_fields") != [] or entry.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
    if set(observed_keys) != set(expected_keys) or len(observed_keys) != len(expected_keys):
        errors.append(f"{label}.observed must cover expected keys exactly")
    observed_digest = report.get("observed_digest")
    if not _digest(observed_digest):
        errors.append(f"{label}.observed_digest must be lowercase SHA-256")
    elif observed_digest != _observed_digest(observed):
        errors.append(f"{label}.observed_digest must match observed entries")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"expected": len(expected_keys), "observed": len(observed), "complete": complete_count, "mutations": mutation_count}
        for key, value in expected_counts.items():
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
        print("NETWORK_SNAPSHOT_COMPLETENESS_AUTHORITY_DIGEST_V18_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_COMPLETENESS_AUTHORITY_DIGEST_V18_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
