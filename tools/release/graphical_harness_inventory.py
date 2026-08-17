#!/usr/bin/env python3
"""Validate and inventory the checked-in graphical harness registry.

The discovery rule is intentionally based on observable source properties, not
on a hand-maintained directory list.  A GDScript below ``tests/`` or ``tools/``
is a graphical harness when it is explicitly capture/render named, or when it
both reads a rendered viewport and writes a PNG.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any


DEFAULT_REGISTRY = "tools/release/graphical_harness_registry.json"
DISCOVERY_ROOTS = ("tests", "tools")
RENDER_READBACK_MARKERS = (
    "RenderingServer.frame_post_draw",
    ".get_texture().get_image()",
    "get_viewport().get_texture()",
)
CLASSIFICATIONS = frozenset(("required", "historical", "deprecated"))
REVIEW_STATUSES = frozenset(
    ("reviewed_current", "reviewed_historical", "pending", "retired")
)
RENDER_PROFILES = frozenset(
    (
        "project_forward_plus",
        "forward_plus_2560x1440",
        "forward_plus_1920x1080",
        "forward_plus_1600x900",
        "forward_plus_1280x800",
        "forward_plus_1280x720",
        "forward_plus_runtime_viewport",
    )
)
OUTPUT_CONTRACTS = frozenset(("png", "png_set", "png_set_and_manifest"))
SOURCE_FREEZE_STATUSES = frozenset(("pending", "verified", "not_applicable"))
IMAGE_INVENTORY_STATUSES = frozenset(("pending", "verified", "not_applicable"))
HUMAN_REVIEW_READINESS = frozenset(
    ("pending", "ready", "reviewed", "not_applicable")
)
MANDATORY_REQUIRED_IMAGE_COUNTS = {
    "caption-presenter-forward-render": 1,
    "caption-production-forward-render": 1,
    "cinder-streaming-transition-render": 24,
    "capture-berth-feedback": 15,
    "capture-combat-visuals": 7,
    "capture-hero-cell": 18,
    "capture-jovian-freight-berth": 2,
    "capture-jovian-freighter": 4,
    "capture-player-motion": 9,
    "capture-scenes": 27,
    "capture-station-operations": 7,
    "capture-varied-encounters": 17,
    "capture-zenith-visuals": 7,
}
MANDATORY_REQUIRED_IDS = frozenset(MANDATORY_REQUIRED_IMAGE_COUNTS)
ID_PATTERN = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
ENV_PATTERN = re.compile(r"^[A-Z][A-Z0-9_]*$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
TOP_LEVEL_KEYS = frozenset(("schema_version", "harnesses"))
ENTRY_KEYS = frozenset(
    (
        "id",
        "script",
        "classification",
        "output",
        "render",
        "review_status",
        "source_freeze",
        "image_inventory",
        "human_review",
    )
)
OUTPUT_KEYS = frozenset(("root", "contract", "runtime_override_env"))
RENDER_KEYS = frozenset(("required", "profile"))
SOURCE_FREEZE_KEYS = frozenset(("status", "manifest_sha256"))
IMAGE_INVENTORY_KEYS = frozenset(
    ("status", "expected_png_count", "inventory_sha256")
)
HUMAN_REVIEW_KEYS = frozenset(
    ("readiness", "original_resolution_required", "evidence_reference")
)


@dataclass(frozen=True)
class InventoryResult:
    errors: tuple[str, ...]
    discovered: tuple[str, ...]
    registered: tuple[str, ...]
    classifications: tuple[tuple[str, int], ...]
    fingerprint: str

    @property
    def valid(self) -> bool:
        return not self.errors

    def to_dict(self) -> dict[str, Any]:
        return {
            "valid": self.valid,
            "errors": list(self.errors),
            "discovered": list(self.discovered),
            "registered": list(self.registered),
            "classifications": dict(self.classifications),
            "fingerprint": self.fingerprint,
        }


@dataclass(frozen=True)
class ReadinessBlocker:
    stage: str
    reason: str

    def to_dict(self) -> dict[str, str]:
        return {"stage": self.stage, "reason": self.reason}


@dataclass(frozen=True)
class RequiredHarnessReadiness:
    harness_id: str
    ready: bool
    source_freeze_status: str
    image_inventory_status: str
    declared_png_count: int | None
    human_review_readiness: str
    original_resolution_required: bool | None
    blockers: tuple[ReadinessBlocker, ...]

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.harness_id,
            "ready": self.ready,
            "source_freeze_status": self.source_freeze_status,
            "image_inventory_status": self.image_inventory_status,
            "declared_png_count": self.declared_png_count,
            "human_review_readiness": self.human_review_readiness,
            "original_resolution_required": self.original_resolution_required,
            "blockers": [blocker.to_dict() for blocker in self.blockers],
        }


@dataclass(frozen=True)
class RequiredReadinessResult:
    inventory_errors: tuple[str, ...]
    harnesses: tuple[RequiredHarnessReadiness, ...]
    inventory_fingerprint: str
    fingerprint: str

    @property
    def inventory_valid(self) -> bool:
        return not self.inventory_errors

    @property
    def ready(self) -> bool:
        return self.inventory_valid and all(harness.ready for harness in self.harnesses)

    @property
    def blocker_count(self) -> int:
        return sum(len(harness.blockers) for harness in self.harnesses)

    def to_dict(self) -> dict[str, Any]:
        return {
            "ready": self.ready,
            "inventory_valid": self.inventory_valid,
            "required_count": len(self.harnesses),
            "ready_count": sum(harness.ready for harness in self.harnesses),
            "blocker_count": self.blocker_count,
            "inventory_errors": list(self.inventory_errors),
            "harnesses": [harness.to_dict() for harness in self.harnesses],
            "inventory_fingerprint": self.inventory_fingerprint,
            "fingerprint": self.fingerprint,
            "render_execution": False,
            "human_review_performed": False,
        }


class DuplicateJsonKey(ValueError):
    """Raised when a JSON object repeats a key."""


def _reject_duplicate_json_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateJsonKey(f"duplicate JSON key: {key!r}")
        result[key] = value
    return result


def load_registry(path: Path) -> tuple[Any, list[str]]:
    try:
        raw = path.read_text(encoding="utf-8")
    except OSError as error:
        return None, [f"cannot read registry {path}: {error}"]
    try:
        return json.loads(raw, object_pairs_hook=_reject_duplicate_json_keys), []
    except (json.JSONDecodeError, DuplicateJsonKey) as error:
        return None, [f"invalid registry JSON: {error}"]


def _is_render_harness(path: Path, source: str) -> bool:
    explicit_name = path.name.startswith("capture_") or path.name.endswith(
        "_render.gd"
    )
    rendered_png = "save_png" in source and any(
        marker in source for marker in RENDER_READBACK_MARKERS
    )
    return explicit_name or rendered_png


def discover_harnesses(root: Path) -> tuple[tuple[str, ...], tuple[str, ...]]:
    found: list[str] = []
    errors: list[str] = []
    for directory_name in DISCOVERY_ROOTS:
        directory = root / directory_name
        if not directory.is_dir():
            errors.append(f"discovery root is missing: {directory_name}")
            continue
        for path in sorted(directory.rglob("*.gd")):
            try:
                source = path.read_text(encoding="utf-8")
            except (OSError, UnicodeError) as error:
                errors.append(
                    f"cannot read discovery candidate {path.relative_to(root).as_posix()}: {error}"
                )
                continue
            if _is_render_harness(path, source):
                found.append(path.relative_to(root).as_posix())
    return tuple(sorted(found)), tuple(sorted(errors))


def _unknown_keys(value: dict[str, Any], allowed: frozenset[str], label: str) -> list[str]:
    return [f"{label} has unknown field {key!r}" for key in sorted(set(value) - allowed)]


def _is_enum(value: Any, allowed: frozenset[str]) -> bool:
    return isinstance(value, str) and value in allowed


def _is_sha256(value: Any) -> bool:
    return isinstance(value, str) and SHA256_PATTERN.fullmatch(value) is not None


def _is_human_evidence_reference(value: Any) -> bool:
    return (
        isinstance(value, str)
        and bool(value.strip())
        and len(value) <= 512
        and all(ord(character) >= 32 for character in value)
    )


def _safe_script_path(root: Path, value: Any) -> str | None:
    if not isinstance(value, str) or not value:
        return "script must be a non-empty string"
    if "\\" in value or "\0" in value:
        return f"unsafe script path: {value!r}"
    pure = PurePosixPath(value)
    if (
        pure.is_absolute()
        or any(part in ("", ".", "..") for part in pure.parts)
        or pure.as_posix() != value
        or len(pure.parts) < 2
        or pure.parts[0] not in DISCOVERY_ROOTS
        or pure.suffix != ".gd"
    ):
        return f"unsafe script path: {value!r}"
    candidate = root / value
    try:
        if not candidate.resolve(strict=False).is_relative_to(root.resolve()):
            return f"script path escapes repository: {value!r}"
    except OSError:
        return f"cannot resolve script path: {value!r}"
    if candidate.is_symlink():
        return f"script path must not be a symlink: {value!r}"
    return None


def _safe_output_root(value: Any) -> str | None:
    if not isinstance(value, str) or not value:
        return "output.root must be a non-empty string"
    if "\\" in value or "\0" in value or "//" in value.removeprefix("res://").removeprefix("user://"):
        return f"unsafe output root: {value!r}"
    if value.startswith("res://"):
        relative = value.removeprefix("res://")
        allowed = relative == "artifacts" or relative.startswith("artifacts/")
    elif value.startswith("user://"):
        relative = value.removeprefix("user://")
        allowed = bool(relative)
    elif value == "/tmp" or value.startswith("/tmp/"):
        relative = value.removeprefix("/tmp/") if value != "/tmp" else "tmp"
        allowed = True
    else:
        return f"unsafe output root scheme: {value!r}"
    parts = PurePosixPath(relative).parts
    if not allowed or any(part in ("", ".", "..") for part in parts):
        return f"unsafe output root: {value!r}"
    return None


def _validate_output(value: Any, label: str) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label}.output must be an object"]
    errors = _unknown_keys(value, OUTPUT_KEYS, f"{label}.output")
    if not {"root", "contract"}.issubset(value):
        errors.append(f"{label}.output must contain root and contract")
    path_error = _safe_output_root(value.get("root"))
    if path_error:
        errors.append(f"{label}: {path_error}")
    if not _is_enum(value.get("contract"), OUTPUT_CONTRACTS):
        errors.append(
            f"{label}.output.contract must be one of {sorted(OUTPUT_CONTRACTS)}"
        )
    override = value.get("runtime_override_env")
    if override is not None and (
        not isinstance(override, str) or ENV_PATTERN.fullmatch(override) is None
    ):
        errors.append(f"{label}.output.runtime_override_env is invalid")
    return errors


def _validate_render(value: Any, label: str) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label}.render must be an object"]
    errors = _unknown_keys(value, RENDER_KEYS, f"{label}.render")
    if set(value) != set(RENDER_KEYS):
        errors.append(f"{label}.render must contain exactly required and profile")
    if value.get("required") is not True:
        errors.append(f"{label}.render.required must be true for a graphical harness")
    if not _is_enum(value.get("profile"), RENDER_PROFILES):
        errors.append(f"{label}.render.profile must be one of {sorted(RENDER_PROFILES)}")
    return errors


def _validate_source_freeze(value: Any, label: str, classification: Any) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label}.source_freeze must be an object"]
    errors = _unknown_keys(value, SOURCE_FREEZE_KEYS, f"{label}.source_freeze")
    if set(value) != set(SOURCE_FREEZE_KEYS):
        errors.append(
            f"{label}.source_freeze must contain exactly status and manifest_sha256"
        )
    status = value.get("status")
    digest = value.get("manifest_sha256")
    if not _is_enum(status, SOURCE_FREEZE_STATUSES):
        errors.append(
            f"{label}.source_freeze.status must be one of {sorted(SOURCE_FREEZE_STATUSES)}"
        )
    elif status == "verified" and not _is_sha256(digest):
        errors.append(
            f"{label}.source_freeze.manifest_sha256 must be a SHA-256 when verified"
        )
    elif status != "verified" and digest is not None:
        errors.append(
            f"{label}.source_freeze.manifest_sha256 must be null unless verified"
        )
    if status == "not_applicable" and classification != "deprecated":
        errors.append(
            f"{label}.source_freeze may be not_applicable only for deprecated harnesses"
        )
    return errors


def _validate_image_inventory(value: Any, label: str, classification: Any) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label}.image_inventory must be an object"]
    errors = _unknown_keys(value, IMAGE_INVENTORY_KEYS, f"{label}.image_inventory")
    if set(value) != set(IMAGE_INVENTORY_KEYS):
        errors.append(
            f"{label}.image_inventory must contain exactly status, expected_png_count, and inventory_sha256"
        )
    status = value.get("status")
    count = value.get("expected_png_count")
    digest = value.get("inventory_sha256")
    if not _is_enum(status, IMAGE_INVENTORY_STATUSES):
        errors.append(
            f"{label}.image_inventory.status must be one of {sorted(IMAGE_INVENTORY_STATUSES)}"
        )
    if count is not None and (type(count) is not int or count <= 0):
        errors.append(
            f"{label}.image_inventory.expected_png_count must be null or a positive exact integer"
        )
    if status == "verified":
        if type(count) is not int or count <= 0:
            errors.append(
                f"{label}.image_inventory.expected_png_count is required when verified"
            )
        if not _is_sha256(digest):
            errors.append(
                f"{label}.image_inventory.inventory_sha256 must be a SHA-256 when verified"
            )
    elif digest is not None:
        errors.append(
            f"{label}.image_inventory.inventory_sha256 must be null unless verified"
        )
    if status == "not_applicable":
        if classification != "deprecated":
            errors.append(
                f"{label}.image_inventory may be not_applicable only for deprecated harnesses"
            )
        if count is not None:
            errors.append(
                f"{label}.image_inventory.expected_png_count must be null when not_applicable"
            )
    return errors


def _validate_human_review(
    value: Any,
    label: str,
    classification: Any,
    source_freeze: Any,
    image_inventory: Any,
) -> list[str]:
    if not isinstance(value, dict):
        return [f"{label}.human_review must be an object"]
    errors = _unknown_keys(value, HUMAN_REVIEW_KEYS, f"{label}.human_review")
    if set(value) != set(HUMAN_REVIEW_KEYS):
        errors.append(
            f"{label}.human_review must contain exactly readiness, original_resolution_required, and evidence_reference"
        )
    readiness = value.get("readiness")
    original_required = value.get("original_resolution_required")
    evidence = value.get("evidence_reference")
    if not _is_enum(readiness, HUMAN_REVIEW_READINESS):
        errors.append(
            f"{label}.human_review.readiness must be one of {sorted(HUMAN_REVIEW_READINESS)}"
        )
    if type(original_required) is not bool:
        errors.append(
            f"{label}.human_review.original_resolution_required must be a boolean"
        )
    elif readiness != "not_applicable" and not original_required:
        errors.append(
            f"{label}.human_review.original_resolution_required must be true for a graphical harness"
        )
    if evidence is not None and not _is_human_evidence_reference(evidence):
        errors.append(
            f"{label}.human_review.evidence_reference must be null or bounded printable text"
        )
    if readiness in ("pending", "ready", "not_applicable") and evidence is not None:
        errors.append(
            f"{label}.human_review.evidence_reference must be null unless reviewed"
        )
    if readiness == "reviewed" and not isinstance(evidence, str):
        errors.append(
            f"{label}.human_review.evidence_reference is required when reviewed"
        )
    if readiness in ("ready", "reviewed"):
        source_status = (
            source_freeze.get("status") if isinstance(source_freeze, dict) else None
        )
        image_status = (
            image_inventory.get("status") if isinstance(image_inventory, dict) else None
        )
        if source_status != "verified" or image_status != "verified":
            errors.append(
                f"{label}.human_review cannot be ready before source and image evidence are verified"
            )
    if readiness == "not_applicable" and classification != "deprecated":
        errors.append(
            f"{label}.human_review may be not_applicable only for deprecated harnesses"
        )
    return errors


def _validate_entry(root: Path, value: Any, index: int) -> list[str]:
    label = f"harnesses[{index}]"
    if not isinstance(value, dict):
        return [f"{label} must be an object"]
    errors = _unknown_keys(value, ENTRY_KEYS, label)
    if set(value) != set(ENTRY_KEYS):
        missing = sorted(ENTRY_KEYS - set(value))
        if missing:
            errors.append(f"{label} is missing fields: {', '.join(missing)}")
    harness_id = value.get("id")
    if not isinstance(harness_id, str) or ID_PATTERN.fullmatch(harness_id) is None:
        errors.append(f"{label}.id is not a stable kebab-case id")
    path_error = _safe_script_path(root, value.get("script"))
    if path_error:
        errors.append(f"{label}: {path_error}")
    classification = value.get("classification")
    if not _is_enum(classification, CLASSIFICATIONS):
        errors.append(f"{label}.classification must be one of {sorted(CLASSIFICATIONS)}")
    review = value.get("review_status")
    if not _is_enum(review, REVIEW_STATUSES):
        errors.append(f"{label}.review_status must be one of {sorted(REVIEW_STATUSES)}")
    elif classification == "required" and review not in ("reviewed_current", "pending"):
        errors.append(f"{label}: required harness has incompatible review_status {review!r}")
    elif classification == "historical" and review not in ("reviewed_historical", "pending"):
        errors.append(f"{label}: historical harness has incompatible review_status {review!r}")
    elif classification == "deprecated" and review != "retired":
        errors.append(f"{label}: deprecated harness must have review_status 'retired'")
    errors.extend(_validate_output(value.get("output"), label))
    errors.extend(_validate_render(value.get("render"), label))
    errors.extend(
        _validate_source_freeze(value.get("source_freeze"), label, classification)
    )
    errors.extend(
        _validate_image_inventory(value.get("image_inventory"), label, classification)
    )
    errors.extend(
        _validate_human_review(
            value.get("human_review"),
            label,
            classification,
            value.get("source_freeze"),
            value.get("image_inventory"),
        )
    )
    return errors


def _validate_inventory(
    root: Path,
    registry_path: Path,
    *,
    mandatory_required_ids: frozenset[str],
) -> InventoryResult:
    root = root.resolve()
    discovered, discovery_errors = discover_harnesses(root)
    data, load_errors = load_registry(registry_path)
    errors = list(discovery_errors) + load_errors
    entries: list[Any] = []
    if data is not None:
        if not isinstance(data, dict):
            errors.append("registry root must be an object")
        else:
            errors.extend(_unknown_keys(data, TOP_LEVEL_KEYS, "registry"))
            schema_version = data.get("schema_version")
            if type(schema_version) is not int or schema_version != 1:
                errors.append("registry.schema_version must be the exact integer 1")
            raw_entries = data.get("harnesses")
            if not isinstance(raw_entries, list):
                errors.append("registry.harnesses must be an array")
            else:
                entries = raw_entries

    ids: dict[str, int] = {}
    scripts: dict[str, int] = {}
    classifications = {name: 0 for name in sorted(CLASSIFICATIONS)}
    canonical_entries: list[dict[str, Any]] = []
    for index, entry in enumerate(entries):
        errors.extend(_validate_entry(root, entry, index))
        if not isinstance(entry, dict):
            continue
        harness_id = entry.get("id")
        script = entry.get("script")
        if isinstance(harness_id, str):
            if harness_id in ids:
                errors.append(
                    f"duplicate harness id {harness_id!r} at indexes {ids[harness_id]} and {index}"
                )
            else:
                ids[harness_id] = index
        if isinstance(script, str):
            if script in scripts:
                errors.append(
                    f"duplicate harness script {script!r} at indexes {scripts[script]} and {index}"
                )
            else:
                scripts[script] = index
            candidate = root / script
            if _safe_script_path(root, script) is None and not candidate.is_file():
                errors.append(f"registered harness script is missing: {script}")
        classification = entry.get("classification")
        if isinstance(classification, str) and classification in classifications:
            classifications[classification] += 1
        canonical_entries.append(entry)

    for mandatory_id in sorted(mandatory_required_ids):
        entry_index = ids.get(mandatory_id)
        if entry_index is None:
            errors.append(f"mandatory required harness id is missing: {mandatory_id}")
            continue
        mandatory_entry = entries[entry_index]
        if not isinstance(mandatory_entry, dict):
            continue
        if mandatory_entry.get("classification") != "required":
            errors.append(f"mandatory required harness was demoted: {mandatory_id}")
        if mandatory_id in MANDATORY_REQUIRED_IMAGE_COUNTS:
            image_inventory = mandatory_entry.get("image_inventory")
            expected_count = (
                image_inventory.get("expected_png_count")
                if isinstance(image_inventory, dict)
                else None
            )
            frozen_count = MANDATORY_REQUIRED_IMAGE_COUNTS[mandatory_id]
            if type(expected_count) is not int or expected_count != frozen_count:
                errors.append(
                    f"mandatory required harness image count drifted: {mandatory_id} "
                    f"({expected_count!r} != {frozen_count})"
                )

    discovered_set = set(discovered)
    registered_set = set(scripts)
    for path in sorted(discovered_set - registered_set):
        errors.append(f"unregistered graphical harness: {path}")
    for path in sorted(registered_set - discovered_set):
        errors.append(f"registered script is not a discovered graphical harness: {path}")

    canonical_payload = {
        "schema_version": 1,
        "discovered": list(discovered),
        "harnesses": sorted(
            canonical_entries,
            key=lambda item: (
                str(item.get("script", "")) if isinstance(item, dict) else "",
                str(item.get("id", "")) if isinstance(item, dict) else "",
            ),
        ),
    }
    fingerprint = hashlib.sha256(
        json.dumps(
            canonical_payload, sort_keys=True, separators=(",", ":"), ensure_ascii=True
        ).encode("ascii")
    ).hexdigest()
    return InventoryResult(
        errors=tuple(sorted(set(errors))),
        discovered=discovered,
        registered=tuple(sorted(registered_set)),
        classifications=tuple(sorted(classifications.items())),
        fingerprint=fingerprint,
    )


def validate_inventory(root: Path, registry_path: Path) -> InventoryResult:
    """Validate with the non-overridable checked-in required-harness policy."""
    return _validate_inventory(
        root,
        registry_path,
        mandatory_required_ids=MANDATORY_REQUIRED_IDS,
    )


def _normalized_status(value: Any, allowed: frozenset[str]) -> str:
    return value if _is_enum(value, allowed) else "invalid"


def _required_harness_readiness(
    harness_id: str,
    entry: dict[str, Any] | None,
    frozen_png_count: int,
) -> RequiredHarnessReadiness:
    if entry is None:
        return RequiredHarnessReadiness(
            harness_id=harness_id,
            ready=False,
            source_freeze_status="missing",
            image_inventory_status="missing",
            declared_png_count=None,
            human_review_readiness="missing",
            original_resolution_required=None,
            blockers=(
                ReadinessBlocker("source_freeze", "harness_missing"),
                ReadinessBlocker("declared_image_inventory", "harness_missing"),
                ReadinessBlocker(
                    "original_resolution_human_review", "harness_missing"
                ),
            ),
        )

    source = entry.get("source_freeze")
    source = source if isinstance(source, dict) else {}
    source_status = _normalized_status(
        source.get("status"), SOURCE_FREEZE_STATUSES
    )
    source_ready = source_status == "verified" and _is_sha256(
        source.get("manifest_sha256")
    )

    image = entry.get("image_inventory")
    image = image if isinstance(image, dict) else {}
    image_status = _normalized_status(
        image.get("status"), IMAGE_INVENTORY_STATUSES
    )
    raw_count = image.get("expected_png_count")
    declared_count = raw_count if type(raw_count) is int else None
    image_ready = (
        image_status == "verified"
        and declared_count == frozen_png_count
        and _is_sha256(image.get("inventory_sha256"))
    )

    human = entry.get("human_review")
    human = human if isinstance(human, dict) else {}
    human_readiness = _normalized_status(
        human.get("readiness"), HUMAN_REVIEW_READINESS
    )
    raw_original_required = human.get("original_resolution_required")
    original_required = (
        raw_original_required if type(raw_original_required) is bool else None
    )
    evidence = human.get("evidence_reference")
    human_ready = (
        human_readiness == "reviewed"
        and original_required is True
        and _is_human_evidence_reference(evidence)
        and source_ready
        and image_ready
    )

    blockers: list[ReadinessBlocker] = []
    if not source_ready:
        source_reason = (
            f"status_{source_status}"
            if source_status != "verified"
            else "manifest_sha256_invalid"
        )
        blockers.append(ReadinessBlocker("source_freeze", source_reason))
    if not image_ready:
        if image_status != "verified":
            image_reason = f"status_{image_status}"
        elif declared_count != frozen_png_count:
            image_reason = "declared_png_count_mismatch"
        else:
            image_reason = "inventory_sha256_invalid"
        blockers.append(
            ReadinessBlocker("declared_image_inventory", image_reason)
        )
    if not human_ready:
        if original_required is not True:
            human_reason = "original_resolution_not_required"
        elif human_readiness == "pending":
            human_reason = "readiness_pending"
        elif human_readiness == "ready":
            human_reason = "awaiting_original_resolution_human_review"
        elif human_readiness != "reviewed":
            human_reason = f"readiness_{human_readiness}"
        elif not _is_human_evidence_reference(evidence):
            human_reason = "evidence_reference_invalid"
        else:
            human_reason = "machine_evidence_incomplete"
        blockers.append(
            ReadinessBlocker("original_resolution_human_review", human_reason)
        )

    return RequiredHarnessReadiness(
        harness_id=harness_id,
        ready=not blockers,
        source_freeze_status=source_status,
        image_inventory_status=image_status,
        declared_png_count=declared_count,
        human_review_readiness=human_readiness,
        original_resolution_required=original_required,
        blockers=tuple(blockers),
    )


def _evaluate_required_readiness(
    root: Path,
    registry_path: Path,
    *,
    mandatory_image_counts: dict[str, int],
) -> RequiredReadinessResult:
    inventory_result = _validate_inventory(
        root,
        registry_path,
        mandatory_required_ids=frozenset(mandatory_image_counts),
    )
    data, _load_errors = load_registry(registry_path)
    rows_by_id: dict[str, dict[str, Any]] = {}
    if isinstance(data, dict) and isinstance(data.get("harnesses"), list):
        for raw_entry in data["harnesses"]:
            if not isinstance(raw_entry, dict):
                continue
            harness_id = raw_entry.get("id")
            if isinstance(harness_id, str) and harness_id not in rows_by_id:
                rows_by_id[harness_id] = raw_entry

    harnesses = tuple(
        _required_harness_readiness(
            harness_id,
            rows_by_id.get(harness_id),
            mandatory_image_counts[harness_id],
        )
        for harness_id in sorted(mandatory_image_counts)
    )
    inventory_errors = tuple(inventory_result.errors)
    canonical_payload = {
        "inventory_errors": list(inventory_errors),
        "inventory_fingerprint": inventory_result.fingerprint,
        "harnesses": [harness.to_dict() for harness in harnesses],
        "render_execution": False,
        "human_review_performed": False,
    }
    fingerprint = hashlib.sha256(
        json.dumps(
            canonical_payload,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=True,
        ).encode("ascii")
    ).hexdigest()
    return RequiredReadinessResult(
        inventory_errors=inventory_errors,
        harnesses=harnesses,
        inventory_fingerprint=inventory_result.fingerprint,
        fingerprint=fingerprint,
    )


def evaluate_required_readiness(
    root: Path, registry_path: Path
) -> RequiredReadinessResult:
    """Report readiness for the non-overridable thirteen required harnesses."""
    return _evaluate_required_readiness(
        root,
        registry_path,
        mandatory_image_counts=MANDATORY_REQUIRED_IMAGE_COUNTS,
    )


def _parse_args(argv: list[str] | None) -> argparse.Namespace:
    default_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=default_root)
    parser.add_argument("--registry", type=Path)
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument(
        "--required-readiness",
        action="store_true",
        help="report metadata-only readiness for the thirteen mandatory harnesses",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="exit nonzero when required readiness has any blocker",
    )
    args = parser.parse_args(argv)
    if args.strict and not args.required_readiness:
        parser.error("--strict requires --required-readiness")
    if args.registry is None:
        args.registry = args.root / DEFAULT_REGISTRY
    return args


def _print_required_readiness(result: RequiredReadinessResult) -> None:
    if not result.inventory_valid:
        status = "INVALID"
    elif result.ready:
        status = "READY"
    else:
        status = "BLOCKED"
    ready_count = sum(harness.ready for harness in result.harnesses)
    print(
        f"REQUIRED_GRAPHICAL_READINESS_{status}: "
        f"ready={ready_count} required={len(result.harnesses)} "
        f"blockers={result.blocker_count} fingerprint={result.fingerprint}"
    )
    for error in result.inventory_errors:
        print(f"INVENTORY_ERROR: {error}")
    for harness in result.harnesses:
        count = (
            str(harness.declared_png_count)
            if harness.declared_png_count is not None
            else "null"
        )
        original_required = (
            str(harness.original_resolution_required).lower()
            if harness.original_resolution_required is not None
            else "null"
        )
        print(
            f"HARNESS: id={harness.harness_id} ready={str(harness.ready).lower()} "
            f"source_freeze={harness.source_freeze_status} "
            f"declared_image_inventory={harness.image_inventory_status} "
            f"declared_png_count={count} "
            f"original_resolution_required={original_required} "
            f"original_resolution_human_review={harness.human_review_readiness}"
        )
        for blocker in harness.blockers:
            print(
                f"BLOCKER: id={harness.harness_id} "
                f"stage={blocker.stage} reason={blocker.reason}"
            )
    print("AUTHORITY: render_execution=false human_review_performed=false")


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    if args.required_readiness:
        readiness = evaluate_required_readiness(args.root, args.registry)
        if args.as_json:
            print(
                json.dumps(
                    readiness.to_dict(), sort_keys=True, separators=(",", ":")
                )
            )
        else:
            _print_required_readiness(readiness)
        if not readiness.inventory_valid:
            return 1
        return 1 if args.strict and not readiness.ready else 0

    result = validate_inventory(args.root, args.registry)
    if args.as_json:
        print(json.dumps(result.to_dict(), sort_keys=True, separators=(",", ":")))
    elif result.valid:
        counts = dict(result.classifications)
        print(
            "GRAPHICAL_HARNESS_INVENTORY_OK: "
            f"discovered={len(result.discovered)} registered={len(result.registered)} "
            f"required={counts['required']} historical={counts['historical']} "
            f"deprecated={counts['deprecated']} fingerprint={result.fingerprint}"
        )
    else:
        print(f"GRAPHICAL_HARNESS_INVENTORY_FAILED: {len(result.errors)} error(s)")
        for error in result.errors:
            print(f"ERROR: {error}")
    return 0 if result.valid else 1


if __name__ == "__main__":
    sys.exit(main())
