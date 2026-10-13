#!/usr/bin/env python3
"""Reject unusable authored inputs before a release export creates artifacts."""

import hashlib
import json
from pathlib import Path
import sys


MANIFEST = "assets/models/zenith/zenith_authored_asset_manifest.json"
RAW_FILES = {
    "assets/models/zenith/zenith_authored_art.glb": "glb_sha256",
    "art_source/zenith/zenith_authored_v1.blend": "blend_sha256",
}


def check_inputs(root: Path) -> None:
    manifest = json.loads((root / MANIFEST).read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("authored asset manifest must be an object")
    for relative_path, hash_key in RAW_FILES.items():
        payload = (root / relative_path).read_bytes()
        if not payload:
            raise ValueError(f"authored source is empty: {relative_path}")
        if hashlib.sha256(payload).hexdigest() != manifest.get(hash_key):
            raise ValueError(f"authored source hash differs from manifest: {relative_path}")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check_zenith_export_inputs.py REPOSITORY", file=sys.stderr)
        return 2
    try:
        check_inputs(Path(sys.argv[1]))
    except (OSError, ValueError) as error:
        print(f"Zenith authored export input error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
