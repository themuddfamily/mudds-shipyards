#!/usr/bin/env python3
"""Record whether a native package artifact is available for later testing.

This probe is intentionally observational: it never exports, launches, or
calls platform-specific tooling.  A present file is only *artifact evidence*,
not proof that the package runs natively.
"""

import argparse
import hashlib
import json
import platform
import sys
from datetime import datetime, timezone
from pathlib import Path


def inspect_package(path: Path) -> dict:
    path = path.expanduser().resolve()
    if not path.is_file():
        return {
            "status": "MISSING",
            "native_execution_status": "NOT_RUN",
            "package_path": str(path),
            "package_name": path.name,
            "native_execution_required": True,
        }
    digest = hashlib.sha256()
    size = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1 << 20), b""):
            digest.update(chunk)
            size += len(chunk)
    modified = datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat()
    return {
        "status": "PRESENT",
        "native_execution_status": "NOT_RUN",
        "package_path": str(path),
        "package_name": path.name,
        "package_size_bytes": size,
        "package_sha256": digest.hexdigest(),
        "package_modified_utc": modified,
        "probe_host_os": platform.system(),
        "probe_host_architecture": platform.machine(),
        "native_execution_required": True,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    result = inspect_package(args.package)
    encoded = json.dumps(result, sort_keys=True, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded, end="")
    return 0 if result["status"] == "PRESENT" else 2


if __name__ == "__main__":
    sys.exit(main())
