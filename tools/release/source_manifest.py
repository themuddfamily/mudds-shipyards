#!/usr/bin/env python3
"""Write the existing matrix source CSV without spawning tools for every file."""
from __future__ import annotations

import argparse
import csv
import hashlib
import os
from pathlib import Path


def source_files(root: Path, scope: list[str]) -> list[Path]:
    files = []
    for entry in scope:
        candidate = root / entry
        # Match the old explicit `-f` scope, including a directly named symlink
        # to a regular file. Recursive find -type f excludes symlinks entirely.
        if candidate.is_file():
            files.append(candidate)
        elif candidate.is_dir() and not candidate.is_symlink():
            def fail(error):
                raise error
            for directory, _, names in os.walk(candidate, followlinks=False, onerror=fail):
                for name in names:
                    path = Path(directory) / name
                    if not path.is_symlink() and path.is_file():
                        files.append(path)
    # Preserve duplicate entries from overlapping scope roots and bytewise order.
    return sorted(files, key=lambda path: os.fsencode(path))


def write_manifest(root: Path, scope: list[str], output: Path) -> None:
    files = source_files(root, scope)
    with output.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, lineterminator="\n")
        writer.writerow(("path", "size_bytes", "sha256"))
        for path in files:
            # GNU stat without -L measured the link itself for explicit symlinks;
            # sha256sum followed it. Preserve that existing freeze contract.
            size = path.lstat().st_size
            digest = hashlib.sha256()
            with path.open("rb") as source:
                while chunk := source.read(1024 * 1024):
                    digest.update(chunk)
            writer.writerow((path.relative_to(root).as_posix(), size, digest.hexdigest()))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("scope", nargs="+")
    args = parser.parse_args()
    write_manifest(args.root, args.scope, args.output)


if __name__ == "__main__":
    main()
