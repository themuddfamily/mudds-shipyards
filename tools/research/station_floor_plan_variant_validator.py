"""Validate the bounded station floor-plan variant manifest.

The floor-plan catalog is an evidence register, not a recovered map.  This
validator keeps the distinction executable: every variant must cite anchored
source material and claims registered by that material, while adjacency and
scale remain uncertain and no row may authenticate a historical floor plan.

The validator intentionally does not inspect scene geometry or infer edges
from the live station.  A future source revision may add a new variant, but it
must pass the same provenance and epistemic-boundary checks first.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
DOCUMENT_ID = "keth_station_floor_plan_variants"
ALLOWED_SCOPES = frozenset(
    {"original_era_observed", "observed_build", "later_source_only"}
)
REQUIRED_CANONICAL_GATES = frozenset(
    {"adjacency_resolved", "scale_resolved", "version_conflicts_resolved"}
)
REQUIRED_RESOLUTION_FIELDS = frozenset({"adjacency", "scale", "version_conflicts"})
AUTHENTICATED_TERMS = frozenset(
    {"authenticated", "canonical", "recovered", "original floor plan"}
)


def _read_json(path: str | Path) -> Any:
    """Read JSON while keeping malformed-file reporting in ``validate``."""

    return json.loads(Path(path).read_text(encoding="utf-8"))


def _is_nonempty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _string_list(value: Any) -> list[str] | None:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        return None
    return [item for item in value if item.strip()]


def _source_anchor_is_registered(anchor: Any) -> bool:
    """Return whether an anchor has enough shape to identify an observation."""

    if not isinstance(anchor, dict):
        return False
    has_time = isinstance(anchor.get("time_ms"), (int, float))
    has_frame = isinstance(anchor.get("frame_zero_based"), int)
    return (has_time or has_frame) and _is_nonempty_string(anchor.get("observation"))


def _contains_authenticated_claim(value: Any) -> bool:
    if not isinstance(value, str):
        return False
    normalized = value.casefold()
    return any(term in normalized for term in AUTHENTICATED_TERMS)


def validate_manifest(
    manifest_path: str | Path,
    ledger_path: str | Path,
) -> list[str]:
    """Return fail-closed errors for a station floor-plan catalog.

    ``ledger_path`` is required deliberately.  A variant without a registered
    source anchor is not evidence, even when its prose sounds cautious.
    """

    errors: list[str] = []
    try:
        document = _read_json(manifest_path)
    except (OSError, json.JSONDecodeError) as exc:
        return [f"manifest cannot be read as JSON: {exc}"]
    try:
        ledger = _read_json(ledger_path)
    except (OSError, json.JSONDecodeError) as exc:
        return [f"source ledger cannot be read as JSON: {exc}"]

    if not isinstance(document, dict):
        return ["manifest root must be an object"]
    if not isinstance(ledger, dict):
        return ["source ledger root must be an object"]

    if document.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"schema_version must be {SCHEMA_VERSION}")
    if document.get("document_id") != DOCUMENT_ID:
        errors.append(f"document_id must be {DOCUMENT_ID}")

    policy = document.get("policy")
    if not isinstance(policy, dict):
        errors.append("policy must be an object")
        policy = {}
    canonical_requires = policy.get("canonical_variant_requires")
    if not isinstance(canonical_requires, list) or set(canonical_requires) != REQUIRED_CANONICAL_GATES:
        errors.append("canonical promotion gates must be adjacency, scale, and version-conflict resolution")
    if policy.get("current_canonical_variant", "missing") is not None:
        errors.append("current_canonical_variant must remain null")
    if policy.get("historical_authentication") != "none":
        errors.append("historical_authentication must remain none")

    source_map: dict[str, dict[str, Any]] = {}
    sources = ledger.get("sources")
    if not isinstance(sources, list):
        errors.append("source ledger sources must be an array")
        sources = []
    for index, source in enumerate(sources):
        if not isinstance(source, dict) or not _is_nonempty_string(source.get("id")):
            errors.append(f"source ledger row {index + 1} has no stable id")
            continue
        source_id = str(source["id"])
        if source_id in source_map:
            errors.append(f"source ledger has duplicate id {source_id}")
        source_map[source_id] = source

    variants = document.get("variants")
    if not isinstance(variants, list) or not variants:
        errors.append("manifest variants must be a non-empty array")
        variants = []
    seen_variant_ids: set[str] = set()
    for index, variant in enumerate(variants):
        prefix = f"variant {index + 1}"
        if not isinstance(variant, dict):
            errors.append(f"{prefix} must be an object")
            continue
        variant_id = variant.get("variant_id")
        if not _is_nonempty_string(variant_id):
            errors.append(f"{prefix} must have a stable variant_id")
            variant_id = f"{prefix} (unnamed)"
        else:
            variant_id = str(variant_id)
            if variant_id in seen_variant_ids:
                errors.append(f"{prefix} duplicates variant_id {variant_id}")
            seen_variant_ids.add(variant_id)
        label = f"{prefix} {variant_id}"

        if variant.get("scope") not in ALLOWED_SCOPES:
            errors.append(f"{label} has an invalid evidence scope")
        if variant.get("disposition") != "deferred":
            errors.append(f"{label} must remain deferred")
        reason = variant.get("reason")
        if not _is_nonempty_string(reason):
            errors.append(f"{label} must explain its uncertainty")

        source_ids = _string_list(variant.get("source_ids"))
        claim_ids = _string_list(variant.get("claim_ids"))
        if not source_ids:
            errors.append(f"{label} must cite at least one source")
            source_ids = []
        if not claim_ids:
            errors.append(f"{label} must cite at least one registered claim")
            claim_ids = []
        if source_ids and len(source_ids) != len(set(source_ids)):
            errors.append(f"{label} has duplicate source_ids")
        if claim_ids and len(claim_ids) != len(set(claim_ids)):
            errors.append(f"{label} has duplicate claim_ids")

        for source_id in source_ids:
            source = source_map.get(source_id)
            if source is None:
                errors.append(f"{label} cites unregistered source {source_id}")
                continue
            anchors = source.get("anchors")
            if not isinstance(anchors, list) or not anchors:
                errors.append(f"{label} cites source {source_id} without observation anchors")
            elif not any(_source_anchor_is_registered(anchor) for anchor in anchors):
                errors.append(f"{label} cites source {source_id} without a registered time/frame observation")
            supported = source.get("claims_supported")
            if not isinstance(supported, list):
                supported = []
            for claim_id in claim_ids:
                if claim_id not in supported:
                    errors.append(f"{label} claim {claim_id} is not supported by source {source_id}")

        resolved = variant.get("resolved")
        if not isinstance(resolved, dict):
            errors.append(f"{label} must type adjacency, scale, and version resolution")
            resolved = {}
        for field in REQUIRED_RESOLUTION_FIELDS:
            if not isinstance(resolved.get(field), bool):
                errors.append(f"{label} resolution field {field} must be boolean")
        if resolved.get("adjacency") is not False:
            errors.append(f"{label} must retain adjacency uncertainty")
        if resolved.get("scale") is not False:
            errors.append(f"{label} must retain scale uncertainty")

        # Optional future confidence/status fields are checked if introduced;
        # current rows are bounded by the deferred disposition and policy.
        for field in ("confidence", "status", "claim", "historical_status"):
            if _contains_authenticated_claim(variant.get(field)):
                errors.append(f"{label} contains an authenticated historical claim in {field}")
        if _contains_authenticated_claim(reason):
            errors.append(f"{label} reason contains an authenticated historical claim")

    return errors


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args()
    errors = validate_manifest(args.manifest, args.ledger)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print("STATION_FLOOR_PLAN_VARIANT_MANIFEST_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
