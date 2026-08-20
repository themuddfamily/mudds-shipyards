#!/usr/bin/env python3
"""Validate structured end-to-end playtest findings and their closure evidence.

This is an evidence gate, not a substitute for a human playing the package.
It requires an explicit human-run state and prevents P0/P1 findings from being
silently marked resolved without reproducible regression and package evidence.
"""

from __future__ import annotations

import json
from pathlib import Path

SCHEMA = "playtest_issue_manifest_v1"
SEVERITIES = {"P0", "P1", "P2"}
ISSUE_STATUSES = {"open", "closed", "accepted_risk"}
HUMAN_RUN_STATUSES = {"NOT_RUN", "IN_PROGRESS", "COMPLETE"}


def _text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(manifest_path: Path) -> list[str]:
    """Return blocking errors; an empty list means the manifest is coherent."""
    try:
        data = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest unreadable: {exc}"]
    errors: list[str] = []
    required = ("schema", "human_run_status", "human_run_evidence", "issues")
    errors.extend(f"manifest missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    run_status = data["human_run_status"]
    if run_status not in HUMAN_RUN_STATUSES:
        errors.append("human_run_status must be NOT_RUN, IN_PROGRESS, or COMPLETE")
    if run_status == "NOT_RUN" and data["human_run_evidence"] is not None:
        errors.append("human_run_evidence must be null when human_run_status is NOT_RUN")
    if run_status != "NOT_RUN" and not _text(data["human_run_evidence"]):
        errors.append("human_run_evidence is required when a human run started")
    issues = data["issues"]
    if not isinstance(issues, list):
        return errors + ["issues must be a list"]
    seen: set[str] = set()
    for index, issue in enumerate(issues):
        label = f"issues[{index}]"
        if not isinstance(issue, dict):
            errors.append(f"{label} must be an object")
            continue
        issue_id = issue.get("id")
        if not _text(issue_id) or issue_id in seen:
            errors.append(f"{label}.id must be a unique non-empty string")
        else:
            seen.add(issue_id)
        severity = issue.get("severity")
        if severity not in SEVERITIES:
            errors.append(f"{label}.severity must be P0, P1, or P2")
        if not _text(issue.get("title")):
            errors.append(f"{label}.title is required")
        steps = issue.get("repro_steps")
        if not isinstance(steps, list) or not steps or any(not _text(step) for step in steps):
            errors.append(f"{label}.repro_steps must contain non-empty steps")
        evidence = issue.get("evidence")
        if not isinstance(evidence, list) or not evidence or any(not _text(item) for item in evidence):
            errors.append(f"{label}.evidence must contain at least one reference")
        status = issue.get("status")
        if status not in ISSUE_STATUSES:
            errors.append(f"{label}.status must be open, closed, or accepted_risk")
        if severity in {"P0", "P1"} and status in {"closed", "accepted_risk"}:
            closure = issue.get("closure")
            if not isinstance(closure, dict):
                errors.append(f"{label}.closure is required for closed P0/P1 findings")
            else:
                for key in ("regression_evidence", "package_evidence", "independent_verification"):
                    if not _text(closure.get(key)):
                        errors.append(f"{label}.closure.{key} is required for closed P0/P1 findings")
    return errors


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    errors = validate(args.manifest.resolve())
    if errors:
        for error in errors:
            print(f"PLAYTEST_ISSUE_MANIFEST_FAILED: {error}")
        return 1
    print(f"PLAYTEST_ISSUE_MANIFEST_VALID: {args.manifest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
