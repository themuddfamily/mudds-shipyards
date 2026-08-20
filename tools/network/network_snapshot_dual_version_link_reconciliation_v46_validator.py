#!/usr/bin/env python3
"""Validate v46 dual-version link/reconciliation evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 46
EVIDENCE_SCOPE = "network_snapshot_dual_version_link_reconciliation_v46"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
AUTHORITY_VERSION = 1
PROVENANCE_VERSION = 1
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _binding_digest(link: dict[str, Any]) -> str:
    return hashlib.sha256(f"{link.get('authority')}|{link.get('authority_version')}|{link.get('provenance_version')}|{link.get('link_id')}|{link.get('source_digest')}|{link.get('target_digest')}".encode("utf-8")).hexdigest()


def _root_digest(links: list[dict[str, Any]]) -> str:
    return hashlib.sha256("\n".join(f"{link.get('order')}|{link.get('link_id')}|{link.get('binding_digest')}" for link in links).encode("utf-8")).hexdigest()


def validate_links(report: Any, label: str = "links") -> list[str]:
    """Return dual-version reconciliation links, root, count, and mutation errors."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (("schema_version", SCHEMA_VERSION), ("evidence_scope", EVIDENCE_SCOPE), ("evidence_mode", EVIDENCE_MODE), ("policy_version", POLICY_VERSION), ("authority", AUTHORITY), ("authority_version", AUTHORITY_VERSION), ("provenance_version", PROVENANCE_VERSION)):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")
    for key in ("snapshot_detached", "no_mutation_guarantee"):
        if report.get(key) is not True:
            errors.append(f"{label}.{key} must be true")

    links = report.get("links")
    if not isinstance(links, list):
        errors.append(f"{label}.links must be an array")
        links = []
    ids: set[str] = set()
    reconciled_count = 0
    mutation_count = 0
    for index, link in enumerate(links):
        prefix = f"{label}.links[{index}]"
        if not isinstance(link, dict):
            errors.append(f"{prefix} must be an object")
            continue
        if link.get("order") != index + 1:
            errors.append(f"{prefix}.order must be {index + 1}")
        link_id = link.get("link_id")
        if not isinstance(link_id, str) or not link_id:
            errors.append(f"{prefix}.link_id must be non-empty")
        elif link_id in ids:
            errors.append(f"{prefix}.link_id must be unique")
        else:
            ids.add(link_id)
        if link.get("authority") != AUTHORITY:
            errors.append(f"{prefix}.authority must be {AUTHORITY}")
        if link.get("authority_version") != AUTHORITY_VERSION:
            errors.append(f"{prefix}.authority_version must be {AUTHORITY_VERSION}")
        if link.get("provenance_version") != PROVENANCE_VERSION:
            errors.append(f"{prefix}.provenance_version must be {PROVENANCE_VERSION}")
        if not _sequence(link.get("sequence")):
            errors.append(f"{prefix}.sequence must be non-negative")
        if not _digest(link.get("source_digest")) or not _digest(link.get("target_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        elif link.get("source_digest") != link.get("target_digest"):
            errors.append(f"{prefix}.target_digest must match source digest")
        binding_digest = link.get("binding_digest")
        if not _digest(binding_digest):
            errors.append(f"{prefix}.binding_digest must be lowercase SHA-256")
        elif binding_digest != _binding_digest(link):
            errors.append(f"{prefix}.binding_digest must bind dual-version link")
        if link.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            reconciled_count += 1
        if link.get("mutation_fields") != [] or link.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
    root_digest = report.get("link_root")
    if not _digest(root_digest):
        errors.append(f"{label}.link_root must be lowercase SHA-256")
    elif root_digest != _root_digest(links):
        errors.append(f"{label}.link_root must match dual-version links")
    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"links": len(links), "unique": len(ids), "reconciled": reconciled_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match link reconciliation")
        if counts.get("mutations") != 0:
            errors.append(f"{label}.counts.mutations must be zero")
    return errors


def validate_links_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_links(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("links", type=Path)
    args = parser.parse_args()
    errors = validate_links_file(args.links)
    if errors:
        print("NETWORK_SNAPSHOT_DUAL_VERSION_LINK_RECONCILIATION_V46_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_DUAL_VERSION_LINK_RECONCILIATION_V46_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
