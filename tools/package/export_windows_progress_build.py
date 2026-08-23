#!/usr/bin/env python3
"""Export a Windows progress build only from a source-clean worktree.

Generated outputs under ``builds/`` are ignored by the preflight; every other
tracked or untracked path blocks export so the artifact cannot be mislabeled as
a reproducible commit build.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

from tools.package.windows_distribution_assembler import assemble_distribution
from tools.package.windows_portable_installer import _read_archive


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


def export_and_assemble(
    root: Path,
    output: Path,
    version: str,
    readme: Path,
    license_file: Path,
    config: Path,
    runner=subprocess.run,
    assembler=assemble_distribution,
    archive_verify=_read_archive,
) -> dict[str, object]:
    """Export and publish an assembled package only after every check passes."""
    output = output if output.is_absolute() else root / output
    output = output.resolve()
    if output.relative_to(root.resolve()).parts[0] != "builds":
        raise ValueError("Windows progress output must be under builds/")
    assert_source_clean(root, runner)
    commit_result = runner(["git", "rev-parse", "HEAD"], cwd=root, check=True, capture_output=True, text=True)
    source_commit = commit_result.stdout.strip()
    if not source_commit:
        raise ValueError("unable to determine source commit")
    staging_parent = root / "builds"
    staging_parent.mkdir(parents=True, exist_ok=True)
    published: list[Path] = []
    with tempfile.TemporaryDirectory(prefix=".progress-export-", dir=staging_parent) as temporary:
        staging = Path(temporary)
        staged_exe = staging / "MuddsShipyards.exe"
        exported = runner(
            ["godot", "--headless", "--export-release", "Windows Desktop", str(staged_exe)],
            cwd=root,
            check=False,
        )
        if exported.returncode != 0 or not staged_exe.is_file():
            raise RuntimeError(f"Windows export failed with exit code {exported.returncode}")
        assembled = assembler(staged_exe, staging / "distributions", version, source_commit, readme, license_file, config)
        archive = Path(assembled["archive"])
        archive_verify(archive)
        final_archive = root / "builds" / "distributions" / archive.name
        final_directory = root / "builds" / "distributions" / Path(assembled["directory"]).name
        for destination in (output, final_archive, final_directory):
            if destination.exists():
                raise FileExistsError(f"refusing to overwrite existing artifact: {destination}")
        output.parent.mkdir(parents=True, exist_ok=True)
        final_archive.parent.mkdir(parents=True, exist_ok=True)
        temp_exe = output.with_name(output.name + ".publishing")
        temp_archive = final_archive.with_name(final_archive.name + ".publishing")
        temp_directory = final_directory.with_name(final_directory.name + ".publishing")
        try:
            shutil.copyfile(staged_exe, temp_exe)
            shutil.copyfile(archive, temp_archive)
            shutil.copytree(Path(assembled["directory"]), temp_directory)
            for temporary_artifact, destination in ((temp_exe, output), (temp_archive, final_archive), (temp_directory, final_directory)):
                temporary_artifact.replace(destination)
                published.append(destination)
        except Exception:
            for destination in published:
                if destination.is_dir():
                    shutil.rmtree(destination)
                else:
                    destination.unlink(missing_ok=True)
            for temporary_artifact in (temp_exe, temp_archive, temp_directory):
                if temporary_artifact.is_dir():
                    shutil.rmtree(temporary_artifact)
                else:
                    temporary_artifact.unlink(missing_ok=True)
            raise
    return {
        "commit": source_commit,
        "exe": str(output),
        "archive": str(final_archive),
        "exe_size": output.stat().st_size,
        "archive_size": final_archive.stat().st_size,
        "exe_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "archive_sha256": hashlib.sha256(final_archive.read_bytes()).hexdigest(),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("builds/windows/MuddsShipyards.exe"))
    parser.add_argument("--version")
    parser.add_argument("--readme", type=Path, default=Path("README.md"))
    parser.add_argument("--license", dest="license_file", type=Path, required=False)
    parser.add_argument("--config", type=Path, default=Path("project.godot"))
    args = parser.parse_args(argv)
    root = Path(__file__).resolve().parents[2]
    try:
        if not args.version or args.license_file is None:
            raise ValueError("--version and --license are required for atomic export+distribution")
        result = export_and_assemble(root, args.output, args.version, args.readme, args.license_file, args.config)
        print(json.dumps(result, sort_keys=True))
        return 0
    except (ExportBlocked, ValueError, subprocess.CalledProcessError) as error:
        print(f"windows-progress-export: BLOCKED: {error}")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
