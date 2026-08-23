#!/usr/bin/env python3
"""Export a Windows progress build only from a source-clean worktree.

Generated outputs under ``builds/`` are ignored by the preflight; every other
tracked or untracked path blocks export so the artifact cannot be mislabeled as
a reproducible commit build.
"""

from __future__ import annotations

import argparse
import subprocess
from pathlib import Path


class ExportBlocked(RuntimeError):
    """The source tree contains changes outside generated build outputs."""


def dirty_source_paths(status: str) -> list[str]:
    paths: list[str] = []
    for line in status.splitlines():
        if len(line) < 4:
            continue
        path = line[3:]
        if " -> " in path:
            path = path.split(" -> ", 1)[1]
        path = path.strip().strip('"')
        if path and not (path == "builds" or path.startswith("builds/")):
            paths.append(path)
    return paths


def assert_source_clean(root: Path, runner=subprocess.run) -> None:
    result = runner(
        ["git", "status", "--porcelain", "--untracked-files=all"],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    dirty = dirty_source_paths(result.stdout)
    if dirty:
        raise ExportBlocked("source tree is dirty outside builds/: " + ", ".join(dirty))


def export_windows(root: Path, output: Path, runner=subprocess.run) -> int:
    output = output if output.is_absolute() else root / output
    if output.resolve().relative_to(root.resolve()).parts[0] != "builds":
        raise ValueError("Windows progress output must be under builds/")
    assert_source_clean(root, runner)
    completed = runner(
        ["godot", "--headless", "--export-release", "Windows Desktop", str(output)],
        cwd=root,
        check=False,
    )
    return int(completed.returncode)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("builds/windows/MuddsShipyards.exe"))
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[2]
    try:
        return export_windows(root, args.output)
    except (ExportBlocked, ValueError, subprocess.CalledProcessError) as error:
        print(f"windows-progress-export: BLOCKED: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
