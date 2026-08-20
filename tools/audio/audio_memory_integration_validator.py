#!/usr/bin/env python3
"""Validate the joined authored-audio memory, routing, and listening record.

The record intentionally keeps deterministic resource evidence separate from
native-output evidence.  A headless census can establish the declared voice
ceiling and decoded stream bytes, but it cannot establish mixer behaviour,
bus balance, or audibility.  Those claims require explicit native provenance
and (for a listening pass) a real reviewer/device record.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
ROUTING_STATUSES = {"DECLARED", "CAPTURED", "NOT_RUN"}
NATIVE_STATUSES = {"CAPTURED", "NOT_RUN", "UNKNOWN"}
LISTENING_STATUSES = {"PASS", "FAIL", "OUTSTANDING", "NOT_RUN"}


def _text(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _non_negative_integer(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def _unique_texts(value: Any, *, non_empty: bool = True) -> bool:
    return (
        isinstance(value, list)
        and (bool(value) or not non_empty)
        and all(_text(item) for item in value)
        and len(value) == len(set(value))
    )


def _required_text(errors: list[str], row: dict[str, Any], key: str, prefix: str) -> None:
    if not _text(row.get(key)):
        errors.append(f"{prefix}.{key} is required")


def validate_manifest(manifest: Any, label: str = "manifest") -> list[str]:
    """Return blocking structural and claim-safety errors."""
    if not isinstance(manifest, dict):
        return [f"{label} must be an object"]
    errors: list[str] = []
    if manifest.get("schema_version") != SCHEMA_VERSION:
        errors.append(f"{label}.schema_version must be {SCHEMA_VERSION}")
    for key in ("audit_id", "build_label", "source_commit"):
        _required_text(errors, manifest, key, label)

    voice = manifest.get("voice_ceiling")
    if not isinstance(voice, dict):
        errors.append(f"{label}.voice_ceiling must be an object")
        voice = {}
    for key in ("declared", "observed_peak"):
        if not _non_negative_integer(voice.get(key)):
            errors.append(f"{label}.voice_ceiling.{key} must be a non-negative integer")
    if (
        _non_negative_integer(voice.get("declared"))
        and _non_negative_integer(voice.get("observed_peak"))
        and voice["observed_peak"] > voice["declared"]
    ):
        errors.append(f"{label}.voice_ceiling.observed_peak exceeds declared ceiling")
    _required_text(errors, voice, "evidence", f"{label}.voice_ceiling")

    memory = manifest.get("stream_memory")
    if not isinstance(memory, dict):
        errors.append(f"{label}.stream_memory must be an object")
        memory = {}
    for key in ("retained_unique_streams", "decoded_payload_bytes", "declared_bytes_ceiling"):
        if not _non_negative_integer(memory.get(key)):
            errors.append(f"{label}.stream_memory.{key} must be a non-negative integer")
    if (
        _non_negative_integer(memory.get("decoded_payload_bytes"))
        and _non_negative_integer(memory.get("declared_bytes_ceiling"))
        and memory["decoded_payload_bytes"] > memory["declared_bytes_ceiling"]
    ):
        errors.append(f"{label}.stream_memory.decoded_payload_bytes exceeds declared ceiling")
    _required_text(errors, memory, "evidence", f"{label}.stream_memory")

    routing = manifest.get("bus_routing")
    if not isinstance(routing, dict):
        errors.append(f"{label}.bus_routing must be an object")
        routing = {}
    routing_status = routing.get("status")
    if routing_status not in ROUTING_STATUSES:
        errors.append(f"{label}.bus_routing.status is invalid")
    buses = routing.get("buses")
    if not isinstance(buses, list) or not buses:
        errors.append(f"{label}.bus_routing.buses must be a non-empty array")
        buses = []
    names: set[str] = set()
    for index, bus in enumerate(buses):
        prefix = f"{label}.bus_routing.buses[{index}]"
        if not isinstance(bus, dict):
            errors.append(f"{prefix} must be an object")
            continue
        name = bus.get("name")
        if not _text(name):
            errors.append(f"{prefix}.name is required")
        elif name in names:
            errors.append(f"{prefix}.name is duplicated")
        else:
            names.add(name)
        _required_text(errors, bus, "target", prefix)
        if bus.get("status") not in ROUTING_STATUSES:
            errors.append(f"{prefix}.status is invalid")
        if bus.get("status") == "CAPTURED":
            _required_text(errors, bus, "evidence", prefix)
    if routing_status == "CAPTURED" and not all(
        isinstance(bus, dict) and bus.get("status") == "CAPTURED" for bus in buses
    ):
        errors.append(f"{label}.bus_routing.CAPTURED requires every bus to be CAPTURED")

    native = manifest.get("native_provenance")
    if not isinstance(native, dict):
        errors.append(f"{label}.native_provenance must be an object")
        native = {}
    native_status = native.get("status")
    if native_status not in NATIVE_STATUSES:
        errors.append(f"{label}.native_provenance.status is invalid")
    if native_status == "CAPTURED":
        if native.get("backend") != "native_output":
            errors.append(f"{label}.native_provenance.CAPTURED requires native_output backend")
        _required_text(errors, native, "device", f"{label}.native_provenance")
        _required_text(errors, native, "evidence", f"{label}.native_provenance")
    elif native_status in {"NOT_RUN", "UNKNOWN"}:
        _required_text(errors, native, "notes", f"{label}.native_provenance")
    if routing_status == "CAPTURED" and native_status != "CAPTURED":
        errors.append(f"{label}.bus_routing.CAPTURED requires captured native provenance")

    listening = manifest.get("human_listening")
    if not isinstance(listening, dict):
        errors.append(f"{label}.human_listening must be an object")
        listening = {}
    listening_status = listening.get("status")
    if listening_status not in LISTENING_STATUSES:
        errors.append(f"{label}.human_listening.status is invalid")
    if listening_status == "PASS":
        for key in ("reviewer", "device", "notes"):
            _required_text(errors, listening, key, f"{label}.human_listening")
        for key in ("mix_levels", "distances"):
            if not _unique_texts(listening.get(key)):
                errors.append(f"{label}.human_listening.{key} must be a non-empty unique array")
        if native_status != "CAPTURED":
            errors.append(f"{label}.human_listening.PASS requires captured native provenance")
    elif listening_status in {"OUTSTANDING", "NOT_RUN"}:
        _required_text(errors, listening, "notes", f"{label}.human_listening")
    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    errors = validate_manifest(json.loads(args.manifest.read_text(encoding="utf-8")))
    if errors:
        print("AUDIO_MEMORY_INTEGRATION_INVALID")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print("AUDIO_MEMORY_INTEGRATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
