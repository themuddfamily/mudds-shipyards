"""Conservative final source/evidence audit for roadmap review handoff.

This is a provenance completeness gate, not an authentication decision.  It
checks that the frozen source IDs, confidence vocabulary, rights cautions and
anchor provenance remain internally consistent, and explicitly rejects an
authenticated claim in this handoff.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

SCHEMA = "final_source_evidence_audit_v1"
ALLOWED = {"authenticated", "bounded_partial_reconstruction", "provisional_candidate", "modern_interpretation", "unknown"}

def _load(path: Path) -> tuple[Any, list[str]]:
    try:
        return json.loads(path.read_text(encoding="utf-8")), []
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        return None, [f"{path}: unreadable: {exc}"]

def _sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def validate(manifest_path: Path) -> list[str]:
    data, errors = _load(manifest_path)
    if not isinstance(data, dict):
        return errors or ["manifest root must be an object"]
    if data.get("schema") != SCHEMA:
        errors.append("unsupported schema")
    if data.get("authentication_claim") is not False:
        errors.append("authentication_claim must remain false")
    ledger_ref = data.get("ledger")
    if not isinstance(ledger_ref, dict) or not isinstance(ledger_ref.get("path"), str):
        return errors + ["ledger.path is required"]
    ledger_path = manifest_path.parent / ledger_ref["path"]
    ledger, load_errors = _load(ledger_path)
    errors.extend(load_errors)
    if not isinstance(ledger, dict):
        return errors
    expected_hash = ledger_ref.get("sha256")
    if not isinstance(expected_hash, str) or len(expected_hash) != 64:
        errors.append("ledger.sha256 must be a 64-character digest")
    elif _sha(ledger_path) != expected_hash:
        errors.append("ledger SHA-256 does not match manifest")
    sources = ledger.get("sources")
    if not isinstance(sources, list):
        return errors + ["ledger.sources must be a list"]
    actual_ids = [s.get("id") for s in sources if isinstance(s, dict)]
    if len(actual_ids) != len(set(actual_ids)):
        errors.append("ledger source IDs must be unique")
    if sorted(actual_ids) != sorted(data.get("source_ids", [])):
        errors.append("manifest source_ids do not match ledger")
    for source in sources:
        if not isinstance(source, dict):
            errors.append("each source must be an object")
            continue
        sid = source.get("id", "<missing>")
        if source.get("confidence") == "authenticated" or source.get("status") == "authenticated":
            errors.append(f"{sid}: authenticated source claim is forbidden")
        rights = source.get("rights")
        if not isinstance(rights, dict) or not rights.get("permission_status") or not rights.get("redistribution_policy"):
            errors.append(f"{sid}: rights must state permission and redistribution policy")
        for index, anchor in enumerate(source.get("anchors", [])):
            if not isinstance(anchor, dict) or not str(anchor.get("observation", "")).strip():
                errors.append(f"{sid} anchor {index}: observation is required")
            elif not any(isinstance(anchor.get(k), (int, float)) and anchor[k] >= 0 for k in ("time_ms", "frame_zero_based")):
                errors.append(f"{sid} anchor {index}: non-negative time/frame provenance is required")
            elif anchor.get("source_id", sid) != sid:
                errors.append(f"{sid} anchor {index}: source_id mismatch")
    matrix_ref = data.get("matrix")
    if not isinstance(matrix_ref, dict) or not isinstance(matrix_ref.get("path"), str):
        errors.append("matrix.path is required")
    else:
        matrix, matrix_errors = _load(manifest_path.parent / matrix_ref["path"])
        errors.extend(matrix_errors)
        if isinstance(matrix, dict):
            policy = matrix.get("policy", {})
            if policy.get("current_authenticated_ship_count") != 0:
                errors.append("matrix must record zero authenticated ships")
            for ship in matrix.get("ships", []):
                if isinstance(ship, dict) and ship.get("name_to_model_status") == "authenticated":
                    errors.append(f"{ship.get('ship_id')}: authenticated model claim is forbidden")
    return errors

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate(args.manifest.resolve())
    for error in errors:
        print(f"FINAL_SOURCE_EVIDENCE_AUDIT_FAILED: {error}")
    if not errors:
        print("FINAL_SOURCE_EVIDENCE_AUDIT_READY: provenance complete; authentication not claimed")
    return int(bool(errors))

if __name__ == "__main__":
    raise SystemExit(main())
