#!/usr/bin/env python3
"""Validate detached v453 authority/snapshot evidence-artifact evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 453
EVIDENCE_SCOPE = "network_snapshot_authority_evidence_artifact_v453"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
INTEGRITY_GATE_ID = "authority-evidence-artifact-v453"
SNAPSHOT_ID = "snapshot-authority-v336"
ASSERTION_ID = "authority-snapshot-evidence-artifact-assertion-v1"
SOURCE = "server_snapshot"
SNAPSHOT_VERSION = 225
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
NOT_RUN_CHECKS = ("stale_check", "native_run", "hardware_run", "human_review")


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _assertion_digest(item: dict[str, Any]) -> str:
    fields = ("assertion_id", "integrity_gate_id", "snapshot_id", "sequence", "subject", "authority_digest", "snapshot_digest")
    return hashlib.sha256("|".join(str(item.get(key)) for key in fields).encode()).hexdigest()


def _rollup_digest(items: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{item.get('order')}|{item.get('item_id')}|{item.get('assertion_digest')}" for item in items).encode()).hexdigest()


def _validate_not_run(value: Any, path: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f"{path} must be an object with NOT_RUN status")
        return
    if value.get("status") != "NOT_RUN":
        errors.append(f"{path}.status must remain NOT_RUN")
    if value.get("evidence") is not None:
        errors.append(f"{path}.evidence must be null when NOT_RUN")
    if not isinstance(value.get("reason"), str) or not value["reason"].strip():
        errors.append(f"{path}.reason is required when NOT_RUN")


def validate_snapshot(report: Any, label: str = "snapshot") -> list[str]:
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION,
        "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE,
        "policy_version": POLICY_VERSION,
        "authority": AUTHORITY,
        "integrity_gate_id": INTEGRITY_GATE_ID,
        "snapshot_id": SNAPSHOT_ID,
        "assertion_id": ASSERTION_ID,
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
    bindings = (
        ("integrity_gate_id", report.get("integrity_gate_id")),
        ("snapshot_id", report.get("snapshot_id")),
        ("assertion_id", report.get("assertion_id")),
        ("authority", AUTHORITY),
        ("source", report.get("source")),
        ("release", report.get("release")),
        ("version", report.get("snapshot_version")),
    )
    for key, value in bindings:
        if snapshot.get(key) != value:
            errors.append(f"{label}.snapshot.{key} must match authority evidence artifact")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    members = report.get("assertion_members")
    if not isinstance(members, list):
        errors.append(f"{label}.assertion_members must be an array")
        members = []
    identities: set[str] = set()
    asserted = 0
    mutations = 0
    for number, member in enumerate(members):
        path = f"{label}.assertion_members[{number}]"
        if not isinstance(member, dict):
            errors.append(f"{path} must be an object")
            continue
        if member.get("order") != number + 1:
            errors.append(f"{path}.order must be {number + 1}")
        item_id = member.get("item_id")
        if not isinstance(item_id, str) or not item_id:
            errors.append(f"{path}.item_id must be non-empty")
        elif item_id in identities:
            errors.append(f"{path}.item_id must be unique")
        else:
            identities.add(item_id)
        for key, value in (
            ("assertion_id", report.get("assertion_id")),
            ("integrity_gate_id", report.get("integrity_gate_id")),
            ("snapshot_id", report.get("snapshot_id")),
            ("authority", AUTHORITY),
        ):
            if member.get(key) != value:
                errors.append(f"{path}.{key} must bind authority evidence artifact")
        if member.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{path}.sequence must match snapshot")
        if not isinstance(member.get("subject"), str) or not member["subject"]:
            errors.append(f"{path}.subject must be non-empty")
        authority_digest, snapshot_digest = member.get("authority_digest"), member.get("snapshot_digest")
        if not _digest(authority_digest) or not _digest(snapshot_digest):
            errors.append(f"{path} digests must be lowercase SHA-256")
        elif authority_digest != snapshot_digest:
            errors.append(f"{path}.snapshot_digest must match authority digest")
        assertion_digest = member.get("assertion_digest")
        if not _digest(assertion_digest):
            errors.append(f"{path}.assertion_digest must be lowercase SHA-256")
        elif assertion_digest != _assertion_digest(member):
            errors.append(f"{path}.assertion_digest must bind authority evidence artifact")
        if member.get("asserted") is not True:
            errors.append(f"{path}.asserted must be true")
        else:
            asserted += 1
        if member.get("mutation_fields") != [] or member.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{path} must have no mutation")

    rollup_digest = report.get("rollup_digest")
    if not _digest(rollup_digest):
        errors.append(f"{label}.rollup_digest must be lowercase SHA-256")
    elif rollup_digest != _rollup_digest(members):
        errors.append(f"{label}.rollup_digest must match authority evidence members")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {"assertion_members": len(members), "unique": len(identities), "asserted": asserted, "mutations": mutations}
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority evidence members")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_snapshot_file(path: Path) -> list[str]:
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [f"unable to read {path}: {error}"]
    return validate_snapshot(report, str(path))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("snapshot")
    errors = validate_snapshot_file(Path(parser.parse_args().snapshot))
    if errors:
        print("NETWORK_SNAPSHOT_AUTHORITY_EVIDENCE_ARTIFACT_V453_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_EVIDENCE_ARTIFACT_V453_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
