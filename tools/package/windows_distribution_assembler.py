#!/usr/bin/env python3
"""Assemble a deterministic Windows distribution from existing export files.

The assembler only copies already-exported bytes.  It does not export, sign,
install, launch, or claim native/human validation.  Every output is staged
under a versioned directory and archived with fixed ZIP metadata.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import zipfile
from pathlib import Path, PurePosixPath
from typing import Iterable

try:
    from .windows_portable_installer import LAUNCHER_NAME, _launcher_bytes
except ImportError:
    from windows_portable_installer import LAUNCHER_NAME, _launcher_bytes


COMMIT = re.compile(r"^[0-9a-f]{40,64}$")
VERSION = re.compile(r"^v?\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$")
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
ZIP_EPOCH = (2020, 1, 1, 0, 0, 0)


class AssemblyError(ValueError):
    """An assembly input is missing, unsafe, or inconsistent."""


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def _copy(source: Path, destination: Path) -> None:
    if not source.is_file():
        raise AssemblyError(f"missing input file: {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)


def _safe_relative(path: str) -> str:
    candidate = PurePosixPath(path)
    if (
        not path
        or candidate.is_absolute()
        or "\\" in path
        or candidate.as_posix() != path
        or any(part in ("", ".", "..") for part in candidate.parts)
    ):
        raise AssemblyError(f"unsafe distribution path: {path!r}")
    return path


def _validate_identity(version: str, source_commit: str) -> None:
    if not VERSION.fullmatch(version):
        raise AssemblyError(f"invalid release version: {version!r}")
    if not COMMIT.fullmatch(source_commit):
        raise AssemblyError("source commit must be a 40-64 character lowercase hex revision")


def _payload_manifest(stage: Path, paths: Iterable[str]) -> list[dict[str, object]]:
    entries = []
    for relative in sorted(paths):
        path = stage / relative
        entries.append({"path": relative, "size_bytes": path.stat().st_size, "sha256": _sha256(path)})
    return entries


def _install_instructions(manifest: dict[str, object]) -> str:
    installer = manifest["portable_installer"]
    powershell_path = installer["powershell_path"]
    launcher = installer["launcher"]
    return (
        "Mudds Shipyards Windows installation\n"
        "===================================\n\n"
        f"Distribution: {manifest['distribution']}\n"
        f"Source commit: {manifest['source_commit']}\n\n"
        "Unzip this directory, then run these commands from its root in PowerShell:\n\n"
        f'  powershell -NoProfile -ExecutionPolicy Bypass -File .\\{powershell_path.replace("/", "\\")} install -Destination "$env:LOCALAPPDATA\\MuddsShipyards"\n'
        f'  powershell -NoProfile -ExecutionPolicy Bypass -File .\\{powershell_path.replace("/", "\\")} status -Destination "$env:LOCALAPPDATA\\MuddsShipyards"\n'
        f'  powershell -NoProfile -ExecutionPolicy Bypass -File .\\{powershell_path.replace("/", "\\")} rollback -Destination "$env:LOCALAPPDATA\\MuddsShipyards"\n'
        f'  powershell -NoProfile -ExecutionPolicy Bypass -File .\\{powershell_path.replace("/", "\\")} uninstall -Destination "$env:LOCALAPPDATA\\MuddsShipyards"\n\n'
        "Upgrade by running the install command again with a newer distribution.\n"
        "The helper keeps one rollback and preserves files it does not own.\n\n"
        "Optional shortcuts (PowerShell, opt in explicitly):\n"
        f'  powershell -NoProfile -ExecutionPolicy Bypass -File .\\{powershell_path.replace("/", "\\")} install -Destination "$env:LOCALAPPDATA\\MuddsShipyards" -StartMenuShortcut\n'
        f'  powershell -NoProfile -ExecutionPolicy Bypass -File .\\{powershell_path.replace("/", "\\")} install -Destination "$env:LOCALAPPDATA\\MuddsShipyards" -DesktopShortcut\n\n'
        f'  powershell -NoProfile -ExecutionPolicy Bypass -File .\\{powershell_path.replace("/", "\\")} install -Destination "$env:LOCALAPPDATA\\MuddsShipyards" -AddRemovePrograms\n\n'
        "Portable run (no installation):\n"
        f'  .\\{launcher}\n\n'
        "Verify the exported executable before use:\n"
        "  Get-FileHash .\\MuddsShipyards.exe -Algorithm SHA256\n"
        "Compare the result with the MuddsShipyards.exe line in SHA256SUMS.txt.\n\n"
        "Save data: Godot user:// (Windows: %APPDATA%\\Godot\\app_userdata\\Mudds Shipyards).\n"
        "Do not delete that directory when uninstalling the portable distribution.\n\n"
        f"Signing: {manifest['signing']} (this package is unsigned).\n"
        f"Native validation: {manifest['native_validation']}. Human playtest: {manifest['human_playtest']}.\n"
    )


def assemble_distribution(
    artifact: Path,
    output_root: Path,
    version: str,
    source_commit: str,
    readme: Path,
    license_file: Path,
    config: Path,
    pck: Path | None = None,
) -> dict[str, object]:
    """Stage and zip an exported artifact, returning output metadata."""
    _validate_identity(version, source_commit)
    artifact = artifact.resolve()
    output_root = output_root.resolve()
    readme = readme.resolve()
    license_file = license_file.resolve()
    config = config.resolve()
    if artifact.suffix.lower() not in {".exe", ".pck"}:
        raise AssemblyError("artifact must be an .exe or .pck")
    if pck is not None:
        pck = pck.resolve()
        if pck.suffix.lower() != ".pck":
            raise AssemblyError("supplemental PCK must have a .pck suffix")
    short_commit = source_commit[:7]
    distribution_name = f"MuddsShipyards-{version}-{short_commit}"
    stage = output_root / distribution_name
    archive = output_root / f"{distribution_name}.zip"
    if stage.exists() or archive.exists():
        raise AssemblyError(f"distribution output already exists: {stage}")
    output_root.mkdir(parents=True, exist_ok=True)

    artifact_name = "MuddsShipyards.exe" if artifact.suffix.lower() == ".exe" else "MuddsShipyards.pck"
    _copy(artifact, stage / artifact_name)
    if pck is not None:
        _copy(pck, stage / "MuddsShipyards.pck")
    _copy(readme, stage / "README.md")
    _copy(license_file, stage / "LICENSE.txt")
    _copy(config, stage / "config" / "project.godot")
    (stage / LAUNCHER_NAME).write_bytes(_launcher_bytes())
    _copy(Path(__file__), stage / "install" / "windows_portable_installer.py")
    _copy(Path(__file__).with_name("windows_portable_installer.ps1"), stage / "install" / "windows_portable_installer.ps1")
    _copy(Path(__file__).with_name("verify_distribution.ps1"), stage / "install" / "verify_distribution.ps1")
    _copy(Path(__file__).with_name("collect_support_bundle.ps1"), stage / "install" / "collect_support_bundle.ps1")

    payload_paths = [
        artifact_name,
        "README.md",
        "LICENSE.txt",
        "config/project.godot",
        LAUNCHER_NAME,
        "install/windows_portable_installer.py",
        "install/windows_portable_installer.ps1",
        "install/verify_distribution.ps1",
        "install/collect_support_bundle.ps1",
        "INSTALL-WINDOWS.txt",
    ]
    if pck is not None:
        payload_paths.append("MuddsShipyards.pck")
    manifest = {
        "schema_version": 1,
        "distribution": distribution_name,
        "version": version,
        "source_commit": source_commit,
        "signing": "NOT_RUN",
        "native_validation": "NOT_RUN",
        "human_playtest": "NOT_RUN",
        "portable_installer": {
            "path": "install/windows_portable_installer.py",
            "powershell_path": "install/windows_portable_installer.ps1",
            "launcher": LAUNCHER_NAME,
            "commands": ["install", "upgrade", "status", "rollback", "uninstall"],
        },
        "verification_helper": "install/verify_distribution.ps1",
        "support_bundle_helper": "install/collect_support_bundle.ps1",
        "files": [],
    }
    (stage / "INSTALL-WINDOWS.txt").write_text(_install_instructions(manifest), encoding="utf-8", newline="\n")
    entries = _payload_manifest(stage, payload_paths)
    checksum_text = "".join(f"{entry['sha256']}  {entry['path']}\n" for entry in entries)
    (stage / "SHA256SUMS.txt").write_text(checksum_text, encoding="utf-8", newline="\n")
    manifest["files"] = entries
    (stage / "distribution-manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )

    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        all_files = sorted(path.relative_to(stage).as_posix() for path in stage.rglob("*") if path.is_file())
        for relative in all_files:
            info = zipfile.ZipInfo(f"{distribution_name}/{relative}", date_time=ZIP_EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            bundle.writestr(info, (stage / relative).read_bytes())
    return {"directory": stage, "archive": archive, "manifest": manifest}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact", type=Path, required=True)
    parser.add_argument("--pck", type=Path)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--readme", type=Path, required=True)
    parser.add_argument("--license", dest="license_file", type=Path, required=True)
    parser.add_argument("--config", type=Path, required=True)
    args = parser.parse_args(argv)
    try:
        result = assemble_distribution(
            args.artifact,
            args.output_root,
            args.version,
            args.source_commit,
            args.readme,
            args.license_file,
            args.config,
            args.pck,
        )
    except (AssemblyError, OSError, ValueError) as error:
        print(f"windows-distribution: ERROR: {error}")
        return 2
    print(json.dumps({key: str(value) for key, value in result.items() if key != "manifest"}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
