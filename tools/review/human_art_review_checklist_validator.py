#!/usr/bin/env python3
"""Validate the checklist handed to a human visual reviewer.

This records coverage and provenance only.  It deliberately cannot turn an
automated check into an art-quality sign-off.
"""

from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from typing import Any

SCHEMA = "human_art_review_checklist_v1"
DOMAINS = ("station", "cockpit_boarding", "dogfight_damage", "landing", "disembark")
PENDING = {"pending", "not_performed"}
FORBIDDEN = {"approved", "pass", "signed_off", "complete"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def validate(path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"checklist unreadable: {exc}"]
    errors: list[str] = []
    required = ("schema", "human_review_status", "reviewer", "domains", "automated_signoff")
    errors.extend(f"checklist missing required key: {key}" for key in required if key not in data)
    if errors:
        return errors
    if data["schema"] != SCHEMA:
        errors.append(f"unsupported schema: {data['schema']!r}")
    if data["human_review_status"] in FORBIDDEN:
        errors.append("human_review_status cannot claim human approval")
    if data["human_review_status"] not in PENDING:
        errors.append("human_review_status must be pending or not_performed")
    if data["automated_signoff"] is not False:
        errors.append("automated_signoff must be false; automated checks cannot sign off art")
    reviewer = data["reviewer"]
    if not isinstance(reviewer, dict):
        errors.append("reviewer must be an object containing identity, role, and review_date")
    else:
        for key in ("identity", "role", "review_date"):
            if not _text(reviewer.get(key)):
                errors.append(f"reviewer.{key} must be non-empty text")
        if _text(reviewer.get("review_date")):
            try:
                date.fromisoformat(reviewer["review_date"])
            except ValueError:
                errors.append("reviewer.review_date must be ISO-8601 YYYY-MM-DD")
    domains = data["domains"]
    if not isinstance(domains, list):
        return errors + ["domains must be a list"]
    seen: set[str] = set()
    for index, domain in enumerate(domains):
        prefix = f"domain[{index}]"
        if not isinstance(domain, dict):
            errors.append(f"{prefix} must be an object")
            continue
        ident = domain.get("id")
        if ident not in DOMAINS:
            errors.append(f"{prefix}: id must be one of {', '.join(DOMAINS)}")
        elif ident in seen:
            errors.append(f"{prefix}: duplicate id {ident!r}")
        else:
            seen.add(ident)
        if domain.get("review_status") not in PENDING:
            errors.append(f"{prefix}: review_status must be pending or not_performed")
        refs = domain.get("capture_refs")
        if not isinstance(refs, list) or not refs or any(not _text(ref) for ref in refs):
            errors.append(f"{prefix}: capture_refs must contain non-empty references")
        if not _text(domain.get("acceptance")):
            errors.append(f"{prefix}: acceptance is required")
    missing = sorted(set(DOMAINS) - seen)
    if missing:
        errors.append("required domains missing: " + ", ".join(missing))
    return errors


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("checklist", type=Path)
    args = parser.parse_args()
    errors = validate(args.checklist.resolve())
    if errors:
        for error in errors:
            print(f"HUMAN_ART_REVIEW_CHECKLIST_FAILED: {error}")
        return 1
    print(f"HUMAN_ART_REVIEW_CHECKLIST_READY: {args.checklist} (human review remains pending)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
