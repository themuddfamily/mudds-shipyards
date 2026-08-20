"""Conservative cross-reference checks for the research source ledger.

This gate checks citation bookkeeping only.  It deliberately does not turn a
source into authentication: an ``authenticated`` confidence/status requires an
explicit review record, rather than being inferred from a URL or an anchor.
"""
from __future__ import annotations

import json
import re
from datetime import date, datetime
from pathlib import Path
from urllib.parse import urlparse
from typing import Any

STATUSES = {"authenticated", "bounded_partial_reconstruction", "provisional_candidate", "modern_interpretation", "unknown"}
_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _date_value(value: Any) -> bool:
    if value in (None, "unknown"):
        return True
    if not isinstance(value, str):
        return False
    if re.fullmatch(r"\d{4}", value) or re.fullmatch(r"\d+(?:\.\d+)+", value):
        return True
    try:
        if _DATE.fullmatch(value):
            date.fromisoformat(value)
        else:
            datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return True


def validate_ledger(path: str | Path) -> list[str]:
    data = json.loads(Path(path).read_text())
    errors: list[str] = []
    sources = data.get("sources")
    if not isinstance(sources, list):
        return ["sources must be a list"]
    ids: set[str] = set()
    for index, source in enumerate(sources):
        if not isinstance(source, dict):
            errors.append(f"source {index} must be an object")
            continue
        sid = source.get("id")
        if not isinstance(sid, str) or not sid.strip():
            errors.append(f"source {index} requires a non-empty id")
            sid = f"source[{index}]"
        elif sid in ids:
            errors.append(f"duplicate source id: {sid}")
        ids.add(sid)
        for field in ("confidence", "status"):
            value = source.get(field)
            if value is not None and value not in STATUSES:
                errors.append(f"{sid} has invalid {field}: {value}")
        if source.get("confidence") == "authenticated" or source.get("status") == "authenticated":
            review = source.get("authentication_review")
            if not isinstance(review, dict) or not review.get("reviewer") or not review.get("reviewed_on"):
                errors.append(f"{sid} claims authentication without explicit review")
        for artifact in source.get("artifacts", []):
            if not isinstance(artifact, dict):
                errors.append(f"{sid} artifact must be an object")
                continue
            url = artifact.get("url")
            parsed = urlparse(url) if isinstance(url, str) else None
            if parsed is None or parsed.scheme not in {"http", "https"} or not parsed.netloc:
                errors.append(f"{sid} artifact URL must be an absolute http(s) URL")
            if not _date_value(artifact.get("accessed_on")):
                errors.append(f"{sid} artifact has invalid accessed_on date")
        for event in source.get("date_events", []):
            if not isinstance(event, dict) or not _date_value(event.get("value")):
                errors.append(f"{sid} has invalid date event value")
        for anchor in source.get("anchors", []):
            if not isinstance(anchor, dict) or not str(anchor.get("observation", "")).strip():
                errors.append(f"{sid} anchor requires an observation")
                continue
            if not any(isinstance(anchor.get(key), (int, float)) and anchor[key] >= 0 for key in ("time_ms", "frame_zero_based")):
                errors.append(f"{sid} anchor requires non-negative time_ms or frame_zero_based")
            if anchor.get("source_id", sid) != sid:
                errors.append(f"{sid} anchor has mismatched source_id")
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    errors = validate_ledger(root / "docs/research/source_ledger.json")
    if errors:
        print("SOURCE_CURRENT_LEDGER_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_CURRENT_LEDGER_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
