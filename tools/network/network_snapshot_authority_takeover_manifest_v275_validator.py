#!/usr/bin/env python3
"""Validate detached v275 network snapshot authority-takeover manifest evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 275
EVIDENCE_SCOPE = "network_snapshot_authority_takeover_manifest_v275"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
MANIFEST_ID = "server-authority-manifest-v1"
TAKEOVER_TOKEN = "server-authority-takeover-token-v46"
SNAPSHOT_ID = "snapshot-authority-v158"
SOURCE = "server_snapshot"
SNAPSHOT_VERSION = 47
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
NOT_RUN_CHECKS = ("stale_check", "native_run", "hardware_run", "human_review")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _manifest_digest(entry: dict[str, Any]) -> str:
    fields = (
        "manifest_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "component", "entry_id", "expected_digest", "observed_digest",
    )
    return hashlib.sha256("|".join(str(entry.get(field)) for field in fields).encode()).hexdigest()


def _rollup_digest(entries: list[dict[str, Any]]) -> str:
    material = "\n".join(
        f"{entry.get('order')}|{entry.get('entry_id')}|{entry.get('manifest_digest')}"
        for entry in entries
    )
    return hashlib.sha256(material.encode()).hexdigest()


def _validate_not_run(value: Any, prefix: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{prefix} must be an object with NOT_RUN status")
        return
    if value.get("status") != "NOT_RUN":
        errors.append(f"{prefix}.status must remain NOT_RUN")
    if value.get("evidence") is not None:
        errors.append(f"{prefix}.evidence must be null when NOT_RUN")
    if not isinstance(value.get("reason"), str) or not value["reason"].strip():
        errors.append(f"{prefix}.reason is required when NOT_RUN")


def validate_snapshot(report: Any, label: str = "snapshot") -> list[str]:
    """Return errors for detached authority-takeover manifest evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION,
        "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE,
        "policy_version": POLICY_VERSION,
        "authority": AUTHORITY,
        "manifest_id": MANIFEST_ID,
        "takeover_token": TAKEOVER_TOKEN,
        "snapshot_id": SNAPSHOT_ID,
        "source": SOURCE,
        "snapshot_version": SNAPSHOT_VERSION,
        "release": RELEASE_ID,
    }
    for key, value in expected.items():
        if report.get(key) != value:
            errors.append(f"{label}.{key} must be {value}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")
    for key in NOT_RUN_CHECKS:
        _validate_not_run(report.get(key), f"{label}.{key}", errors)

    snapshot = report.get("snapshot")
    if not isinstance(snapshot, dict):
        errors.append(f"{label}.snapshot must be an object")
        snapshot = {}
    snapshot_fields = (
        ("manifest_id", report.get("manifest_id")),
        ("takeover_token", report.get("takeover_token")),
        ("snapshot_id", report.get("snapshot_id")),
        ("authority", AUTHORITY), ("source", report.get("source")),
        ("release", report.get("release")), ("version", report.get("snapshot_version")),
    )
    for key, value in snapshot_fields:
        if snapshot.get(key) != value:
            errors.append(f"{label}.snapshot.{key} must match authority manifest")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    entries = report.get("manifest_entries")
    if not isinstance(entries, list):
        errors.append(f"{label}.manifest_entries must be an array")
        entries = []
    ids: set[str] = set()
    listed = mutations = 0
    for index, entry in enumerate(entries):
        prefix = f"{label}.manifest_entries[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if entry.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        entry_id = entry.get("entry_id")
        if not isinstance(entry_id, str) or not entry_id:
            errors.append(f"{prefix}.entry_id must be non-empty")
        elif entry_id in ids:
            errors.append(f"{prefix}.entry_id must be unique")
        else:
            ids.add(entry_id)
        for key, value in (
            ("manifest_id", report.get("manifest_id")),
            ("takeover_token", report.get("takeover_token")),
            ("snapshot_id", report.get("snapshot_id")),
            ("authority", AUTHORITY),
        ):
            if entry.get(key) != value:
                errors.append(f"{prefix}.{key} must match authority manifest")
        if entry.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        if not isinstance(entry.get("component"), str) or not entry["component"]:
            errors.append(f"{prefix}.component must be non-empty")
        expected_digest = entry.get("expected_digest")
        observed_digest = entry.get("observed_digest")
        if not _digest(expected_digest) or not _digest(observed_digest):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif expected_digest != observed_digest:
            errors.append(f"{prefix}.observed_digest must match expected digest")
        manifest_digest = entry.get("manifest_digest")
        if not _digest(manifest_digest):
            errors.append(f"{prefix}.manifest_digest must be lowercase SHA-256")
        elif manifest_digest != _manifest_digest(entry):
            errors.append(f"{prefix}.manifest_digest must bind authority manifest")
        if entry.get("listed") is not True:
            errors.append(f"{prefix}.listed must be true")
        else:
            listed += 1
        if entry.get("mutation_fields") != [] or entry.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")

    rollup_digest = report.get("rollup_digest")
    if not _digest(rollup_digest):
        errors.append(f"{label}.rollup_digest must be lowercase SHA-256")
    elif rollup_digest != _rollup_digest(entries):
        errors.append(f"{label}.rollup_digest must match authority manifest entries")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {
            "entries": len(entries), "unique": len(ids), "listed": listed, "mutations": mutations,
        }
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority manifest entries")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_snapshot_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_snapshot(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    args = parser.parse_args()
    errors = validate_snapshot_file(args.snapshot)
    if errors:
        print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_MANIFEST_V275_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_MANIFEST_V275_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
