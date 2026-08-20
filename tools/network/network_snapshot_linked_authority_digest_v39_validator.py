#!/usr/bin/env python3
"""Validate v39 linked snapshot authority digest evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 39
EVIDENCE_SCOPE = "network_snapshot_linked_authority_digest_v39"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_replication_interest_authority_v1"
AUTHORITY = "server"
SHA256 = re.compile(r"^[0-9a-f]{64}$")


def _sequence(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _digest(value: Any) -> bool:
    return isinstance(value, str) and SHA256.fullmatch(value) is not None


def _link_digest(link: dict[str, Any]) -> str:
    return hashlib.sha256(f"{AUTHORITY}|{link.get('link_id')}|{link.get('parent_digest')}|{link.get('child_digest')}".encode("utf-8")).hexdigest()


def validate_links(report: Any, label: str = "links") -> list[str]:
    """Return linked chain, authority digest, count, and no-mutation errors."""

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
    if not _sequence(report.get("sequence")):
        errors.append(f"{label}.sequence must be non-negative")
    for key in ("initial_digest", "final_digest"):
        if not _digest(report.get(key)):
            errors.append(f"{label}.{key} must be lowercase SHA-256")

    links = report.get("links")
    if not isinstance(links, list):
        errors.append(f"{label}.links must be an array")
        links = []
    ids: set[str] = set()
    current = report.get("initial_digest")
    valid_count = 0
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
        if not _digest(link.get("parent_digest")) or not _digest(link.get("child_digest")):
            errors.append(f"{prefix} digests must be lowercase SHA-256")
        if link.get("parent_digest") != current:
            errors.append(f"{prefix}.parent_digest must match linked predecessor")
        link_digest = link.get("link_digest")
        if not _digest(link_digest):
            errors.append(f"{prefix}.link_digest must be lowercase SHA-256")
        elif link_digest != _link_digest(link):
            errors.append(f"{prefix}.link_digest must bind linked authority digests")
        if link.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
        else:
            valid_count += 1
        if _digest(link.get("child_digest")):
            current = link["child_digest"]
        if link.get("mutation_fields") != [] or link.get("state_changed") is not False:
            mutation_count += 1
            errors.append(f"{prefix} must have no mutation")
    if _digest(report.get("final_digest")) and current != report.get("final_digest"):
        errors.append(f"{label}.final_digest must match linked chain")

    counts = report.get("counts")
    if not isinstance(counts, dict):
        errors.append(f"{label}.counts must be an object")
    else:
        expected = {"links": len(links), "unique": len(ids), "reconciled": valid_count, "mutations": mutation_count}
        for key, value in expected.items():
            if counts.get(key) != value:
                errors.append(f"{label}.counts.{key} must match linked chain")
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
        print("NETWORK_SNAPSHOT_LINKED_AUTHORITY_DIGEST_V39_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_SNAPSHOT_LINKED_AUTHORITY_DIGEST_V39_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
