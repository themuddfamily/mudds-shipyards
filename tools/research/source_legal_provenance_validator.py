"""Fail-closed rights/provenance checks for external footage and source models.

This is a bookkeeping gate, not a copyright opinion.  Every entry must identify
the source, record the intended internal usage scope, and state what remains
unknown.  The schema deliberately has no positive ``available`` state: the
repository must never turn a discoverable URL into a claim that media or a
licence is available.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

SCHEMA_VERSION = 1
ALLOWED_PERMISSION = {"permission_not_recorded", "permission_requested", "permission_granted"}
FORBIDDEN_KEYS = {"available", "availability", "download_available", "license_available"}


def _strings(value: Any) -> bool:
    return isinstance(value, list) and bool(value) and all(isinstance(v, str) and v.strip() for v in value)


def _walk_for_forbidden(value: Any, path: str = "") -> list[str]:
    errors: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key.casefold() in FORBIDDEN_KEYS:
                errors.append(f"{path}.{key} must not claim availability")
            errors.extend(_walk_for_forbidden(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            errors.extend(_walk_for_forbidden(child, f"{path}[{index}]"))
    return errors


def validate_manifest(path: str | Path) -> list[str]:
    try:
        document = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"cannot read legal provenance ledger: {exc}"]
    errors = _walk_for_forbidden(document, "ledger")
    if not isinstance(document, dict):
        return errors + ["ledger root must be an object"]
    if document.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    policy = document.get("policy")
    if not isinstance(policy, dict) or policy.get("availability_claims") != "forbidden":
        errors.append("policy.availability_claims must be 'forbidden'")
    entries = document.get("sources")
    if not isinstance(entries, list) or not entries:
        return errors + ["sources must be a non-empty list"]
    ids: set[str] = set()
    for index, entry in enumerate(entries):
        prefix = f"sources[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{prefix} must be an object")
            continue
        source_id = entry.get("source_id")
        if not isinstance(source_id, str) or not source_id.strip():
            errors.append(f"{prefix}.source_id is required")
        elif source_id in ids:
            errors.append(f"duplicate source_id: {source_id}")
        else:
            ids.add(source_id)
        urls = entry.get("source_urls")
        if not _strings(urls) or not all(u.startswith(("http://", "https://")) for u in urls):
            errors.append(f"{prefix}.source_urls must contain an http(s) URL")
        if not _strings(entry.get("usage_scope")):
            errors.append(f"{prefix}.usage_scope must be a non-empty list")
        if not isinstance(entry.get("unknowns"), list) or not all(isinstance(v, str) and v.strip() for v in entry["unknowns"]):
            errors.append(f"{prefix}.unknowns must be an explicit string list")
        rights = entry.get("rights")
        if not isinstance(rights, dict):
            errors.append(f"{prefix}.rights is required")
        else:
            if rights.get("permission_status") not in ALLOWED_PERMISSION:
                errors.append(f"{prefix}.rights.permission_status is invalid")
            if rights.get("redistribution_policy") != "do_not_bundle_or_commit":
                errors.append(f"{prefix}.rights.redistribution_policy must forbid bundling")
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    errors = validate_manifest(root / "docs/research/source_legal_provenance.json")
    if errors:
        print("SOURCE_LEGAL_PROVENANCE_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_LEGAL_PROVENANCE_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
