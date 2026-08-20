#!/usr/bin/env python3
"""Validate v10 root-authority digest evidence for snapshot lineage."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 10
EVIDENCE_SCOPE = "network_snapshot_lineage_root_authority_digest_v10"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")
DECISIONS = {"accepted", "rejected_digest", "rejected_sequence"}


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _state(value: Any) -> bool:
    return isinstance(value, dict) and _sequence(value.get("sequence")) and _digest(value.get("digest"))


def _root_digest(authority: str, state: dict[str, Any]) -> str:
    return hashlib.sha256(f"{authority}|{state.get('sequence')}|{state.get('digest')}".encode("utf-8")).hexdigest()


def validate_root(report: Any, label: str = "root") -> list[str]:
    """Return root-anchor, transition-chain, count, and no-mutation errors."""

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
    root_state = {"sequence": root.get("sequence"), "digest": root.get("digest")}
    if not _state(root_state):
        errors.append(f"{label}.root must contain sequence and lowercase SHA-256 digest")
    if not _digest(root.get("authority_digest")):
        errors.append(f"{label}.root.authority_digest must be lowercase SHA-256")
    elif _state(root_state) and root["authority_digest"] != _root_digest(AUTHORITY, root_state):
        errors.append(f"{label}.root.authority_digest must anchor authority and root state")

    final = report.get("final")
    if not _state(final):
        errors.append(f"{label}.final must contain sequence and lowercase SHA-256 digest")
    transitions = report.get("transitions")
    if not isinstance(transitions, list):
        errors.append(f"{label}.transitions must be an array")
        transitions = []
    counts = {decision: 0 for decision in DECISIONS}
    mutation_count = 0
    current = dict(root_state) if _state(root_state) else {}
    for index, transition in enumerate(transitions):
        prefix = f"{label}.transitions[{index}]"
        if not isinstance(transition, dict):
            errors.append(f"{prefix} must be an object")
            continue
        order = index + 1
        if transition.get("order") != order:
            errors.append(f"{prefix}.order must be {order}")
        if transition.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        decision = transition.get("decision")
        if decision not in DECISIONS:
            errors.append(f"{prefix}.decision must be accepted, rejected_digest, or rejected_sequence")
        else:
            counts[decision] += 1
        source = transition.get("from")
        target = transition.get("to")
        if not _state(source):
            errors.append(f"{prefix}.from must contain sequence and lowercase SHA-256 digest")
        elif source != current:
            errors.append(f"{prefix}.from must match root lineage state")
        if not _state(target):
            errors.append(f"{prefix}.to must contain sequence and lowercase SHA-256 digest")
        if decision == "accepted":
            if transition.get("accepted") is not True:
                errors.append(f"{prefix}.accepted must be true")
            if _sequence(current.get("sequence")) and target.get("sequence") != current["sequence"] + 1:
                errors.append(f"{prefix}.to.sequence must advance once")
        elif decision in {"rejected_digest", "rejected_sequence"}:
            if transition.get("accepted") is not False:
                errors.append(f"{prefix}.accepted must be false")
            if _state(source) and _state(target) and target != source:
                errors.append(f"{prefix}.to must equal from for rejected transition")
        if _state(target):
            current = dict(target)
        if transition.get("mutation_fields") != [] or transition.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
    if _state(final) and current != final:
        errors.append(f"{label}.final must match root lineage state")

    counts_report = report.get("counts")
    if not isinstance(counts_report, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {
            "transitions": len(transitions),
            "accepted": counts["accepted"],
            "rejected_digest": counts["rejected_digest"],
            "rejected_sequence": counts["rejected_sequence"],
            "rejected": counts["rejected_digest"] + counts["rejected_sequence"],
            "mutations": mutation_count,
        }
        for key, value in expected.items():
            if counts_report.get(key) != value:
                errors.append(f"{label}.counts.{key} must match root transitions")
        if counts_report.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_root_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_root(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path)
    args = parser.parse_args()
    errors = validate_root_file(args.root)
    if errors:
        print("NETWORK_SNAPSHOT_LINEAGE_ROOT_AUTHORITY_DIGEST_V10_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_LINEAGE_ROOT_AUTHORITY_DIGEST_V10_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
