#!/usr/bin/env python3
"""Validate detached v270 network snapshot authority-takeover handoff evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 270
EVIDENCE_SCOPE = "network_snapshot_authority_takeover_handoff_v270"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
HANDOFF_ID = "server-authority-handoff-v1"
TAKEOVER_TOKEN = "server-authority-takeover-token-v41"
SNAPSHOT_ID = "snapshot-authority-v153"
SOURCE = "server_snapshot"
SNAPSHOT_VERSION = 42
RELEASE_ID = "release-1"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
NOT_RUN_CHECKS = ("stale_check", "native_run", "hardware_run", "human_review")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _handoff_digest(step: dict[str, Any]) -> str:
    fields = (
        "handoff_id", "from_authority", "to_authority", "takeover_token",
        "snapshot_id", "sequence", "phase", "step_id", "expected_digest",
        "observed_digest",
    )
    material = "|".join(str(step.get(field)) for field in fields)
    return hashlib.sha256(material.encode()).hexdigest()


def _ledger_digest(steps: list[dict[str, Any]]) -> str:
    material = "\n".join(
        f"{step.get('order')}|{step.get('step_id')}|{step.get('handoff_digest')}"
        for step in steps
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
    """Return errors for detached authority-takeover handoff evidence."""
    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    expected = {
        "schema_version": SCHEMA_VERSION,
        "evidence_scope": EVIDENCE_SCOPE,
        "evidence_mode": EVIDENCE_MODE,
        "policy_version": POLICY_VERSION,
        "authority": AUTHORITY,
        "handoff_id": HANDOFF_ID,
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
        ("handoff_id", report.get("handoff_id")),
        ("takeover_token", report.get("takeover_token")),
        ("snapshot_id", report.get("snapshot_id")),
        ("authority", AUTHORITY),
        ("source", report.get("source")),
        ("release", report.get("release")),
        ("version", report.get("snapshot_version")),
    )
    for key, value in snapshot_fields:
        if snapshot.get(key) != value:
            errors.append(f"{label}.snapshot.{key} must match authority handoff")
    if not _sequence(snapshot.get("sequence")) or not _digest(snapshot.get("digest")):
        errors.append(f"{label}.snapshot must contain sequence and lowercase SHA-256 digest")

    steps = report.get("handoff_steps")
    if not isinstance(steps, list):
        errors.append(f"{label}.handoff_steps must be an array")
        steps = []
    ids: set[str] = set()
    accepted = mutations = 0
    for index, step in enumerate(steps):
        prefix = f"{label}.handoff_steps[{index}]"
        if not isinstance(step, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if step.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        step_id = step.get("step_id")
        if not isinstance(step_id, str) or not step_id:
            errors.append(f"{prefix}.step_id must be non-empty")
        elif step_id in ids:
            errors.append(f"{prefix}.step_id must be unique")
        else:
            ids.add(step_id)
        for key, value in (
            ("handoff_id", report.get("handoff_id")),
            ("takeover_token", report.get("takeover_token")),
            ("snapshot_id", report.get("snapshot_id")),
            ("to_authority", AUTHORITY),
        ):
            if step.get(key) != value:
                errors.append(f"{prefix}.{key} must match authority handoff")
        if step.get("from_authority") != "peer":
            errors.append(f"{prefix}.from_authority must be peer")
        if step.get("sequence") != snapshot.get("sequence"):
            errors.append(f"{prefix}.sequence must match snapshot")
        if not isinstance(step.get("phase"), str) or not step["phase"]:
            errors.append(f"{prefix}.phase must be non-empty")
        expected_digest = step.get("expected_digest")
        observed_digest = step.get("observed_digest")
        if not _digest(expected_digest) or not _digest(observed_digest):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif expected_digest != observed_digest:
            errors.append(f"{prefix}.observed_digest must match expected digest")
        handoff_digest = step.get("handoff_digest")
        if not _digest(handoff_digest):
            errors.append(f"{prefix}.handoff_digest must be lowercase SHA-256")
        elif handoff_digest != _handoff_digest(step):
            errors.append(f"{prefix}.handoff_digest must bind authority handoff")
        if step.get("accepted") is not True:
            errors.append(f"{prefix}.accepted must be true")
        else:
            accepted += 1
        if step.get("mutation_fields") != [] or step.get("state_changed") is not False:
            mutations += 1
            errors.append(f"{prefix} must have no mutation")

    ledger_digest = report.get("ledger_digest")
    if not _digest(ledger_digest):
        errors.append(f"{label}.ledger_digest must be lowercase SHA-256")
    elif ledger_digest != _ledger_digest(steps):
        errors.append(f"{label}.ledger_digest must match authority handoff steps")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected_counts = {
            "steps": len(steps), "unique": len(ids),
            "accepted": accepted, "mutations": mutations,
        }
        for key, value in expected_counts.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match authority handoff steps")
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
        print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_HANDOFF_V270_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_AUTHORITY_TAKEOVER_HANDOFF_V270_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
