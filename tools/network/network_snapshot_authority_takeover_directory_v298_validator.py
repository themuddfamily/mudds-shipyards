#!/usr/bin/env python3
"""Validate detached v298 network snapshot authority-takeover directory evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 298
EVIDENCE_SCOPE = "network_snapshot_authority_takeover_directory_v298"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
DIRECTORY_ID = "server-authority-directory-v1"
TAKEOVER_TOKEN = "server-authority-takeover-token-v69"
SNAPSHOT_ID = "snapshot-authority-v181"
SOURCE = "server_snapshot"
SNAPSHOT_VERSION = 70
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
NOT_RUN_CHECKS = ("stale_check", "native_run", "hardware_run", "human_review")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _directory_digest(item: dict[str, Any]) -> str:
    fields = (
        "directory_id", "authority", "takeover_token", "snapshot_id", "sequence",
        "path", "item_id", "expected_digest", "observed_digest",
    )
    return hashlib.sha256("|".join(str(item.get(field)) for field in fields).encode()).hexdigest()


def _rollup_digest(items: list[dict[str, Any]]) -> str:
    material = "\n".join(
        f"{item.get('order')}|{item.get('item_id')}|{item.get('directory_digest')}"
        for item in items
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
    """Return errors for detached authority-takeover directory evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION,
        "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE,
        "policy_version": POLICY_VERSION,
        "authority": AUTHORITY,
        "directory_id": DIRECTORY_ID,
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
        ("directory_id", report.get("directory_id")),
        ("takeover_token", report.get("takeover_token")),
        ("snapshot_id", report.get("snapshot_id")),
        ("authority", AUTHORITY), ("source", report.get("source")),
        ("release", report.get("release")), ("version", report.get("snapshot_version")),
    )
    for key, value in snapshot_fields:
        if snapshot.get(key) != value:
            errors.append(f"{label}.snapshot.{key} must match authority directory")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    items = report.get("directory_entries")
    if not isinstance(items, list):
        errors.append(f"{label}.directory_entries must be an array")
        items = []
    ids: set[str] = set()
    located = mutations = 0
    for index, item in enumerate(items):
        prefix = f"{label}.directory_entries[{index}]"
        if not isinstance(item, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if item.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        item_id = item.get("item_id")
        if not isinstance(item_id, str) or not item_id:
            errors.append(f"{prefix}.item_id must be non-empty")
        elif item_id in ids:
            errors.append(f"{prefix}.item_id must be unique")
        else:
            ids.add(item_id)
        for key, value in (
            ("directory_id", report.get("directory_id")),
            ("takeover_token", report.get("takeover_token")),
            ("snapshot_id", report.get("snapshot_id")),
            ("authority", AUTHORITY),
        ):
            if item.get(key) != value:
                errors.append(f"{prefix}.{key} must match authority directory")
        if item.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        if not isinstance(item.get("path"), str) or not item["path"]:
            errors.append(f"{prefix}.path must be non-empty")
        expected_digest = item.get("expected_digest")
        observed_digest = item.get("observed_digest")
        if not _digest(expected_digest) or not _digest(observed_digest):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif expected_digest != observed_digest:
            errors.append(f"{prefix}.observed_digest must match expected digest")
        directory_digest = item.get("directory_digest")
        if not _digest(directory_digest):
            errors.append(f"{prefix}.directory_digest must be lowercase SHA-256")
        elif directory_digest != _directory_digest(item):
            errors.append(f"{prefix}.directory_digest must bind authority directory")
        if item.get("located") is not True:
            errors.append(f"{prefix}.located must be true")
        else:
            located += 1
        if item.get("mutation_fields") != [] or item.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")

    rollup_digest = report.get("rollup_digest")
    if not _digest(rollup_digest):
        errors.append(f"{label}.rollup_digest must be lowercase SHA-256")
    elif rollup_digest != _rollup_digest(items):
        errors.append(f"{label}.rollup_digest must match authority directory entries")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {
            "entries": len(items), "unique": len(ids), "located": located, "mutations": mutations,
        }
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority directory entries")
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
        print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_DIRECTORY_V298_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_DIRECTORY_V298_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
