#!/usr/bin/env python3
"""Validate v43 linked authority/provenance version evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 43
EVIDENCE_SCOPE = "network_snapshot_linked_authority_provenance_version_v43"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
LINK_VERSION = 1
PROVENANCE_VERSION = 1
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _link_digest(link: dict[str, Any]) -> str:
    provenance = link.get("provenance", {})
    payload = f"{AUTHORITY}|{link.get('link_version')}|{link.get('provenance_version')}|{link.get('link_id')}|{provenance.get('event')}|{provenance.get('version')}|{provenance.get('sequence')}|{link.get('parent_digest')}|{link.get('child_digest')}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _provenance_root(links: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{link.get('order')}|{link.get('link_id')}|{link.get('link_digest')}" for link in links).encode("utf-8")).hexdigest()


def validate_versioned(report: Any, label: str = "versioned") -> list[str]:
    """Return dual-version links, chain, root digest, counts, and mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
        ("authority", AUTHORITY),
        ("link_version", LINK_VERSION),
        ("provenance_version", PROVENANCE_VERSION),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")
    for key in ("initial_digest", "final_digest"):
        if not _digest(report.get(key)):
            errors.append(f"{label}.{key} must be lowercase SHA-256")

    links = report.get("links")
    if not isinstance(links, list):
        errors.append(f"{label}.links must be an array")
        links = []
    ids: set[str] = set()
    current = report.get("initial_digest")
    reconciled_count = 0
    mutation_count = 0
    for index, link in enumerate(links):
        prefix = f"{label}.links[{index}]"
        if not isinstance(link, dict):
            errors.append(f"{prefix} must be an object")
            continue
        order = index + 1
        if link.get("order") != order:
            errors.append(f"{prefix}.order must be {order}")
        link_id = link.get("link_id")
        if not isinstance(link_id, str) or not link_id:
            errors.append(f"{prefix}.link_id must be non-empty")
        elif link_id in ids:
            errors.append(f"{prefix}.link_id must be unique")
        else:
            ids.add(link_id)
        if link.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if link.get("link_version") != LINK_VERSION:
            errors.append(f"{prefix}.link_version must be {LINK_VERSION}")
        if link.get("provenance_version") != PROVENANCE_VERSION:
            errors.append(f"{prefix}.provenance_version must be {PROVENANCE_VERSION}")
        provenance = link.get("provenance")
        if not isinstance(provenance, dict):
            errors.append(f"{prefix}.provenance must be an object")
            provenance = {}
        if provenance.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.provenance.authority must be {AUTHORITY}")
        if provenance.get("version") != PROVENANCE_VERSION:
            errors.append(f"{prefix}.provenance.version must be {PROVENANCE_VERSION}")
        if not isinstance(provenance.get("event"), str) or not provenance.get("event"):
            errors.append(f"{prefix}.provenance.event must be non-empty")
        if provenance.get("sequence") != order:
            errors.append(f"{prefix}.provenance.sequence must be {order}")
        if not _digest(link.get("parent_digest")) or not _digest(link.get("child_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        if link.get("parent_digest") != current:
            errors.append(f"{prefix}.parent_digest must match versioned predecessor")
        link_digest = link.get("link_digest")
        if not _digest(link_digest):
            errors.append(f"{prefix}.link_digest must be lowercase SHA-256")
        elif link_digest != _link_digest(link):
            errors.append(f"{prefix}.link_digest must bind both versions")
        if link.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if _digest(link.get("child_digest")):
            current = link["child_digest"]
        if link.get("mutation_fields") != [] or link.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
    if _digest(report.get("final_digest")) and current != report.get("final_digest"):
        errors.append(f"{label}.final_digest must match versioned chain")
    provenance_root = report.get("provenance_root")
    if not _digest(provenance_root):
        errors.append(f"{label}.provenance_root must be lowercase SHA-256")
    elif provenance_root != _provenance_root(links):
        errors.append(f"{label}.provenance_root must match versioned links")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"links": len(links), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match versioned links")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_versioned_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_versioned(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("versioned", type=Path)
    args = parser.parse_args()
    errors = validate_versioned_file(args.versioned)
    if errors:
        print("NETWORK_SNAPSHOT_LINKED_AUTHORITY_PROVENANCE_VERSION_V43_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_LINKED_AUTHORITY_PROVENANCE_VERSION_V43_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
