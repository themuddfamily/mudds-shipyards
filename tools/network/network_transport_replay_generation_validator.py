#!/usr/bin/env python3
"""Validate detached transport replay and generation-fence evidence.

The ledger checks monotonic per-stream sequences, replay rejection, and token
rotation/reset behavior for the existing transport-security contract. It uses
metadata only—no authentication secret, socket, or live-network measurement
is accepted as part of this fixture.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
EVIDENCE_SCOPE = "network_transport_replay_generation"
EVIDENCE_MODE = "detached_contract_fixture"
POLICY_VERSION = "network_transport_security_v1"


def _positive_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value > 0


def _non_negative_int(value: Any) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value >= 0


def validate_ledger(report: Any, label: str = "ledger") -> list[str]:
    """Return replay, cursor, and generation-fence errors for one ledger."""

    errors: list[str] = []
    if not isinstance(report, dict):
        return [f"{label} must be an object"]
    for key, expected in (
        ("schema_version", SCHEMA_VERSION),
        ("evidence_scope", EVIDENCE_SCOPE),
        ("evidence_mode", EVIDENCE_MODE),
        ("policy_version", POLICY_VERSION),
    ):
        if report.get(key) != expected:
            errors.append(f"{label}.{key} must be {expected}")
    for key in ("native_claims", "uses_live_network", "contains_auth_secret"):
        if report.get(key) is not False:
            errors.append(f"{label}.{key} must be false")

    audit = report.get("audit")
    if not isinstance(audit, dict):
        errors.append(f"{label}.audit must be an object")
    else:
        for key in ("server_owns_token_generation", "server_owns_replay_cursor", "stale_generation_rejected"):
            if audit.get(key) is not True:
                errors.append(f"{label}.audit.{key} must be true")
        if audit.get("client_can_mutate_replay_cursor") is not False:
            errors.append(f"{label}.audit.client_can_mutate_replay_cursor must be false")

    peer = report.get("peer")
    if not isinstance(peer, dict):
        errors.append(f"{label}.peer must be an object")
        peer = {}
    if not _positive_int(peer.get("peer_id")):
        errors.append(f"{label}.peer.peer_id must be positive")
    for key in ("generation_before", "generation_after"):
        if not _positive_int(peer.get(key)):
            errors.append(f"{label}.peer.{key} must be positive")
    if _positive_int(peer.get("generation_before")) and _positive_int(peer.get("generation_after")) and peer["generation_after"] <= peer["generation_before"]:
        errors.append(f"{label}.peer.generation_after must advance")

    streams = report.get("streams")
    stream_high_water: dict[str, int] = {}
    if not isinstance(streams, list) or not streams:
        errors.append(f"{label}.streams must be a non-empty array")
        streams = []
    for index, stream in enumerate(streams):
        prefix = f"{label}.streams[{index}]"
        if not isinstance(stream, dict):
            errors.append(f"{prefix} must be an object")
            continue
        stream_id = stream.get("stream_id")
        if not isinstance(stream_id, str) or not stream_id.strip() or stream_id in stream_high_water:
            errors.append(f"{prefix}.stream_id must be unique and non-empty")
            continue
        sequences = stream.get("accepted_sequences")
        if not isinstance(sequences, list) or any(not _non_negative_int(item) for item in sequences):
            errors.append(f"{prefix}.accepted_sequences must be non-negative integers")
            sequences = []
        if sequences != sorted(set(sequences)):
            errors.append(f"{prefix}.accepted_sequences must be strictly increasing")
        high_water = stream.get("high_water_mark")
        if not _non_negative_int(high_water):
            errors.append(f"{prefix}.high_water_mark must be non-negative")
        elif sequences and high_water != sequences[-1]:
            errors.append(f"{prefix}.high_water_mark must equal the last accepted sequence")
        stream_high_water[stream_id] = high_water if _non_negative_int(high_water) else -1
        if stream.get("server_owns_cursor") is not True:
            errors.append(f"{prefix}.server_owns_cursor must be true")

    replays = report.get("replay_rejections")
    if not isinstance(replays, list) or not replays:
        errors.append(f"{label}.replay_rejections must be a non-empty array")
        replays = []
    for index, rejection in enumerate(replays):
        prefix = f"{label}.replay_rejections[{index}]"
        if not isinstance(rejection, dict):
            errors.append(f"{prefix} must be an object")
            continue
        stream_id = rejection.get("stream_id")
        if stream_id not in stream_high_water:
            errors.append(f"{prefix}.stream_id must reference a known stream")
        attempted = rejection.get("attempted_sequence")
        if not _non_negative_int(attempted):
            errors.append(f"{prefix}.attempted_sequence must be non-negative")
        elif stream_id in stream_high_water and attempted > stream_high_water[stream_id]:
            errors.append(f"{prefix}.attempted_sequence must not exceed the stream high-water mark")
        if rejection.get("accepted") is not False or rejection.get("status") != "replayed_or_out_of_order":
            errors.append(f"{prefix} must be a replayed_or_out_of_order rejection")
        if rejection.get("server_rejected") is not True:
            errors.append(f"{prefix}.server_rejected must be true")

    rotation = report.get("token_rotation")
    if not isinstance(rotation, dict):
        errors.append(f"{label}.token_rotation must be an object")
    else:
        if not _positive_int(rotation.get("token_generation_before")) or not _positive_int(rotation.get("token_generation_after")) or rotation.get("token_generation_after", 0) <= rotation.get("token_generation_before", 0):
            errors.append(f"{label}.token_rotation token generation must advance")
        for key in ("token_changed", "stream_cursors_reset", "server_committed"):
            if rotation.get(key) is not True:
                errors.append(f"{label}.token_rotation.{key} must be true")
        if rotation.get("contains_token_material") is not False:
            errors.append(f"{label}.token_rotation.contains_token_material must be false")

    fence = report.get("generation_fence")
    if not isinstance(fence, dict):
        errors.append(f"{label}.generation_fence must be an object")
    else:
        old = fence.get("old_generation_packet")
        new = fence.get("new_generation_packet")
        if not isinstance(old, dict) or old.get("accepted") is not False or old.get("status") != "stale_peer_generation":
            errors.append(f"{label}.generation_fence.old_generation_packet must be rejected as stale_peer_generation")
        if not isinstance(new, dict) or new.get("accepted") is not True or new.get("status") != "packet_accepted":
            errors.append(f"{label}.generation_fence.new_generation_packet must be accepted")
        if isinstance(old, dict) and old.get("source_peer_id") != old.get("packet_peer_id"):
            errors.append(f"{label}.generation_fence.old packet source must match packet peer")
        if isinstance(new, dict) and new.get("source_peer_id") != new.get("packet_peer_id"):
            errors.append(f"{label}.generation_fence.new packet source must match packet peer")
        if fence.get("stale_packet_altered_cursor") is not False:
            errors.append(f"{label}.generation_fence.stale_packet_altered_cursor must be false")
    return errors


def validate_ledger_file(report_path: Path) -> list[str]:
    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"unable to read {report_path}: {exc}"]
    return validate_ledger(report, str(report_path))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ledger", type=Path)
    args = parser.parse_args()
    errors = validate_ledger_file(args.ledger)
    if errors:
        print("NETWORK_TRANSPORT_REPLAY_GENERATION_INVALID")
        for error in errors:
            print(f"- {error}")
        return 1
    print("NETWORK_TRANSPORT_REPLAY_GENERATION_VALID")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
