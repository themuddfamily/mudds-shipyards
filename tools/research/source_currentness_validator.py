"""Small, dependency-free gate for historical evidence currentness.

This is deliberately a source-level check: it does not authenticate footage or
decide whether a reconstruction is good.  It catches the easy-to-miss drift
where a matrix row points at a missing anchor, confidence is silently raised,
or an unknown date is presented as authentication.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

STATUSES = {
    "authenticated",
    "bounded_partial_reconstruction",
    "provisional_candidate",
    "modern_interpretation",
    "unknown",
}


def validate_manifest(ledger_path: str | Path, matrix_path: str | Path) -> list[str]:
    ledger = json.loads(Path(ledger_path).read_text())
    matrix = json.loads(Path(matrix_path).read_text())
    errors: list[str] = []
    sources = {s.get("id"): s for s in ledger.get("sources", [])}
    if len(sources) != len(ledger.get("sources", [])):
        errors.append("ledger source IDs must be unique")
    artifacts: set[str] = set()
    for source_id, source in sources.items():
        for artifact in source.get("artifacts", []):
            aid = artifact.get("artifact_id")
            if aid in artifacts:
                errors.append(f"duplicate artifact_id: {aid}")
            artifacts.add(aid)
        for index, anchor in enumerate(source.get("anchors", [])):
            if not anchor.get("observation"):
                errors.append(f"{source_id} anchor {index} has no observation")
            if not any(k in anchor for k in ("time_ms", "frame_zero_based")):
                errors.append(f"{source_id} anchor {index} has no time/frame provenance")
            if "source_id" in anchor and anchor["source_id"] != source_id:
                errors.append(f"{source_id} anchor {index} has mismatched source_id")

    policy = matrix.get("policy", {})
    vocabulary = set(policy.get("evidence_status_vocabulary", STATUSES))
    if vocabulary != STATUSES:
        errors.append("matrix confidence vocabulary does not match the ledger policy")
    authenticated = 0
    for ship in matrix.get("ships", []):
        sid = ship.get("ship_id", "<unnamed>")
        status = ship.get("name_to_model_status")
        if status not in STATUSES:
            errors.append(f"{sid} has invalid confidence status: {status}")
        if status == "authenticated":
            authenticated += 1
        unknowns = ship.get("unknowns")
        if status in {"bounded_partial_reconstruction", "provisional_candidate", "unknown"} and not isinstance(unknowns, list):
            errors.append(f"{sid} must retain an explicit unknowns list")
        refs = ship.get("model_sources", []) + ship.get("name_only_sources", []) + ship.get("creator_roster_sources", [])
        for ref in refs:
            if ref not in sources:
                errors.append(f"{sid} references unregistered source {ref}")
        if status == "authenticated":
            if not ship.get("model_sources"):
                errors.append(f"{sid} claims authentication without model provenance")
            if unknowns:
                errors.append(f"{sid} claims authentication while retaining unknowns")
    declared = policy.get("current_authenticated_ship_count")
    if declared != authenticated:
        errors.append(f"authenticated count is {declared}, but rows contain {authenticated}")
    if authenticated:
        errors.append("historical authentication claims require explicit manual review")
    return errors


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    errors = validate_manifest(root / "docs/research/source_ledger.json", root / "docs/research/ship_evidence_matrix.json")
    if errors:
        print("SOURCE_CURRENTNESS_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("SOURCE_CURRENTNESS_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
