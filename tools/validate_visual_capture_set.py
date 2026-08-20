#!/usr/bin/env python3
"""Validate a checked-in rendered-evidence capture set without rendering.

This is deliberately a file/manifest gate.  It proves that the frames named by
an evidence manifest still exist, have the declared PNG contract, and have not
changed since the capture record was written.  It does not claim visual
quality, human review, or native-GPU behaviour.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def fail(message: str) -> None:
    raise ValueError(message)


def png_header(path: Path) -> tuple[int, int, int, int, int, int, int]:
    data = path.read_bytes()
    if len(data) < 33 or data[:8] != PNG_SIGNATURE:
        fail(f"{path}: invalid PNG signature")
    length = struct.unpack(">I", data[8:12])[0]
    if data[12:16] != b"IHDR" or length != 13 or len(data) < 33:
        fail(f"{path}: missing canonical IHDR")
    return struct.unpack(">IIBBBBB", data[16:29])


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def local_path(project_root: Path, resource_path: str) -> Path:
    if resource_path.startswith("res://"):
        return project_root / resource_path[6:]
    return project_root / resource_path


def validate(project_root: Path, manifest_path: Path) -> int:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    required = ("schema", "frame_count", "frame_inventory", "semantic_state_inventory",
                "capture_resolution", "source_manifest", "source_manifest_sha256",
                "source_file_count", "source_files", "frames")
    for key in required:
        if key not in manifest:
            fail(f"manifest missing required key: {key}")

    if not str(manifest["schema"]).endswith("_v1"):
        fail(f"unsupported manifest schema: {manifest['schema']}")
    frames = manifest["frames"]
    inventory = manifest["frame_inventory"]
    states = manifest["semantic_state_inventory"]
    if manifest["frame_count"] != len(frames) or len(inventory) != len(frames):
        fail("frame_count, frame_inventory, and frames disagree")
    if len(set(inventory)) != len(inventory) or len(set(states)) != len(states):
        fail("frame or semantic-state inventory contains duplicates")
    if len(states) != len(frames):
        fail("semantic-state inventory does not cover every frame")
    resolution = manifest["capture_resolution"]
    if not isinstance(resolution, list) or len(resolution) != 2 or any(int(v) <= 0 for v in resolution):
        fail("capture_resolution must be two positive integers")
    if manifest.get("native_window_size") != resolution:
        fail("native_window_size must match capture_resolution")

    source_manifest = local_path(project_root, manifest["source_manifest"])
    if not source_manifest.is_file():
        fail(f"source manifest not found: {source_manifest}")
    source_digest = sha256(source_manifest)
    if source_digest != manifest["source_manifest_sha256"]:
        fail("source manifest SHA-256 does not match evidence record")
    source_lines = [line for line in source_manifest.read_text(encoding="utf-8").splitlines() if line.strip()]
    if len(source_lines) != manifest["source_file_count"] or len(manifest["source_files"]) != len(source_lines):
        fail("source file count does not match source manifest")
    if any(len(line.split()) != 2 for line in source_lines):
        fail("source manifest contains a malformed line")

    seen_files: set[str] = set()
    seen_states: set[str] = set()
    for frame in frames:
        name = str(frame.get("file", ""))
        state = str(frame.get("semantic_state", ""))
        if not name or name in seen_files or name not in inventory:
            fail(f"frame file is missing or duplicated: {name!r}")
        if not state or state in seen_states or state not in states:
            fail(f"semantic state is missing or duplicated: {state!r}")
        seen_files.add(name)
        seen_states.add(state)
        path = manifest_path.parent / name
        if not path.is_file():
            fail(f"frame not found: {path}")
        width, height, bit_depth, colour_type, compression, filtering, interlace = png_header(path)
        expected_width, expected_height = resolution
        if (width, height) != (expected_width, expected_height):
            fail(f"{path}: resolution {(width, height)} != {resolution}")
        if (bit_depth, colour_type, compression, filtering, interlace) != (8, 2, 0, 0, 0):
            fail(f"{path}: PNG is not RGB8 non-interlaced")
        actual_digest = sha256(path)
        if actual_digest != frame.get("sha256"):
            fail(f"{path}: SHA-256 does not match evidence record")
        if frame.get("png_bytes") != path.stat().st_size:
            fail(f"{path}: byte count does not match evidence record")
    if seen_files != set(inventory) or seen_states != set(states):
        fail("frame inventory is not exactly covered")
    print(f"VISUAL_CAPTURE_SET_OK: {manifest_path} ({len(frames)} frames, {resolution[0]}x{resolution[1]})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path, help="evidence_manifest.json")
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        return validate(args.project_root.resolve(), args.manifest.resolve())
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"VISUAL_CAPTURE_SET_FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
