#!/usr/bin/env python3
"""Validate v11 cleanup root/leaf lineage reconciliation summaries."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


SCHEMA = "audio_cleanup_root_leaf_lineage_reconciliation_summary_v11"
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
    if summary.get("claim") != "AUTOMATED_ROOT_LEAF_RECONCILIATION_ONLY":
        errors.append("claim must be AUTOMATED_ROOT_LEAF_RECONCILIATION_ONLY")
    if not _text(summary.get("boundary_note")):
        errors.append("boundary_note is required")
    root_digest = summary.get("root_digest")
    if not _digest(root_digest):
        errors.append("root_digest must be a lowercase 64-character digest")

    roots = summary.get("roots")
    root_ids: set[str] = set()
    if not isinstance(roots, list) or not roots:
        errors.append("roots must be a non-empty array")
        roots = []
    for index, root in enumerate(roots):
        prefix = f"roots[{index}]"
        if not isinstance(root, dict):
            errors.append(f"{prefix} must be an object")
            continue
        root_id = root.get("root_id")
        if not _text(root_id):
            errors.append(f"{prefix}.root_id is required")
        elif root_id in root_ids:
            errors.append(f"{prefix}.root_id is duplicated")
        else:
            root_ids.add(root_id)
        if root.get("digest") != root_digest:
            errors.append(f"{prefix}.digest must match root_digest")
        if not _text(root.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
    if len(root_ids) != 1:
        errors.append("roots must contain exactly one root_id")

    leaves = summary.get("leaves")
    leaf_ids: set[str] = set()
    if not isinstance(leaves, list) or not leaves:
        errors.append("leaves must be a non-empty array")
        leaves = []
    for index, leaf in enumerate(leaves):
        prefix = f"leaves[{index}]"
        if not isinstance(leaf, dict):
            errors.append(f"{prefix} must be an object")
            continue
        leaf_id = leaf.get("leaf_id")
        if not _text(leaf_id):
            errors.append(f"{prefix}.leaf_id is required")
        elif leaf_id in leaf_ids:
            errors.append(f"{prefix}.leaf_id is duplicated")
        else:
            leaf_ids.add(leaf_id)
        if leaf.get("parent_root_id") not in root_ids:
            errors.append(f"{prefix}.parent_root_id must reference the root")
        if not _digest(leaf.get("digest")):
            errors.append(f"{prefix}.digest must be a lowercase 64-character digest")
        if not _text(leaf.get("evidence")):
            errors.append(f"{prefix}.evidence is required")
        if leaf.get("reconciled") is not True:
            errors.append(f"{prefix}.reconciled must be true")
    if summary.get("reconciliation_pass") is not True:
        errors.append("reconciliation_pass must be true")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("summary", type=Path)
    args = parser.parse_args(argv)
    errors = validate_summary(json.loads(args.summary.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_CLEANUP_ROOT_LEAF_V11_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_CLEANUP_ROOT_LEAF_V11_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
