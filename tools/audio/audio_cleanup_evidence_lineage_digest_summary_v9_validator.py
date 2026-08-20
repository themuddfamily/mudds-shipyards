#!/usr/bin/env python3
"""Validate v9 lineage links for an audio cleanup evidence digest summary."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_evidence_lineage_digest_summary_v9"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _digest(value: Any) -> bool:
    return isinstance(value, str) and bool(SHA256_RE.fullmatch(value))


def validate_summary(summary: Any) -> list[str]:
    if not isinstance(summary, dict):
        return ["summary must be an object"]
    errors: list[str] = []
    if summary.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}")
    for key in ("revision", "owner", "summary_id", "evidence_bundle"):
        if not _text(summary.get(key)):
            errors.append(f"{key} is required")
    if summary.get("claim") != "AUTOMATED_LINEAGE_ONLY":
        errors.append("claim must be AUTOMATED_LINEAGE_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    if not _digest(summary.get("root_digest")):
        errors.append("root_digest must be a lowercase 64-character digest")

    nodes = summary.get("lineage")
    if not isinstance(nodes, list) or not nodes:
        errors.append("lineage must be a non-empty array")
        nodes = []
    ids: set[str] = set()
    parent_ids: list[str] = []
    node_digests: set[str] = set()
    for index, node in enumerate(nodes):
        prefix = f"lineage[{index}]"
        if not isinstance(node, dict):
            errors.append(f"{prefix} must be an object")
            continue
        node_id = node.get("node_id")
        if not _text(node_id):
            errors.append(f"{prefix}.node_id is required")
        elif node_id in ids:
            errors.append(f"{prefix}.node_id is duplicated")
        else:
            ids.add(node_id)
        parent_id = node.get("parent_id")
        if parent_id is not None:
            if not _text(parent_id):
                errors.append(f"{prefix}.parent_id must be a non-empty string or null")
            else:
                parent_ids.append(parent_id)
        digest = node.get("digest")
        if not _digest(digest):
            errors.append(f"{prefix}.digest must be a lowercase 64-character digest")
        else:
            node_digests.add(digest)
        if not _text(node.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if node.get("accepted") is not True:
            errors.append(f"{prefix}.accepted must be true")
    for index, parent_id in enumerate(parent_ids):
        if parent_id not in ids:
            errors.append(f"lineage parent reference {parent_id} is missing")
    roots = [node for node in nodes if isinstance(node, dict) and node.get("parent_id") is None]
    if len(roots) != 1:
        errors.append("lineage must contain exactly one root node")
    elif roots[0].get("digest") != summary.get("root_digest"):
        errors.append("root_digest must match the root node digest")
    if summary.get("lineage_pass") is not True:
        errors.append("lineage_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_LINEAGE_V9_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_LINEAGE_V9_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
