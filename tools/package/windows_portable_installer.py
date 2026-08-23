"""Install, upgrade, and uninstall a non-admin Windows portable package.

The installer consumes a ZIP produced by windows_distribution_assembler.py. It
validates SHA256SUMS.txt before staging, publishes by directory replacement,
keeps one rollback directory, and uninstalls only files listed in its own
ownership manifest. It does not sign, launch, elevate, or touch the registry.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


OWNERSHIP_NAME = ".mudds-owned.json"
ROLLBACK_SUFFIX = ".rollback"
STAGING_SUFFIX = ".staging"
MAX_ARCHIVE_BYTES = 512 * 1024 * 1024


class InstallError(ValueError):
    """The package or explicit destination is unsafe or inconsistent."""


def _relative_name(name: str) -> str:
    candidate = PurePosixPath(name)
    if (
        not name
        or candidate.is_absolute()
        or "\\" in name
        or candidate.as_posix() != name
        or any(part in ("", ".", "..") for part in candidate.parts)
    ):
        raise InstallError(f"unsafe archive path: {name!r}")
    return name


def _destination(path: Path) -> Path:
    resolved = path.expanduser().resolve()
    if resolved == resolved.anchor or resolved.parent == resolved:
        raise InstallError("destination must be a non-root directory")
    return resolved


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _read_checksums(entries: dict[str, bytes], root: str) -> list[str]:
    checksum_name = f"{root}/SHA256SUMS.txt"
    if checksum_name not in entries:
        raise InstallError("package is missing SHA256SUMS.txt")
    checked: list[str] = []
    for line in entries[checksum_name].decode("utf-8").splitlines():
        fields = line.split("  ", 1)
        if len(fields) != 2 or len(fields[0]) != 64 or any(c not in "0123456789abcdef" for c in fields[0]):
            raise InstallError("invalid SHA256SUMS.txt entry")
        relative = _relative_name(fields[1])
        archive_name = f"{root}/{relative}"
        if archive_name not in entries or _sha256_bytes(entries[archive_name]) != fields[0]:
            raise InstallError(f"checksum mismatch: {relative}")
        checked.append(relative)
    if len(set(checked)) != len(checked):
        raise InstallError("duplicate checksum entry")
    listed = {f"{root}/{relative}" for relative in checked}
    allowed_metadata = {f"{root}/distribution-manifest.json", checksum_name}
    if set(entries) - listed - allowed_metadata:
        raise InstallError("archive contains an unlisted payload")
    return checked


def _read_archive(package: Path) -> tuple[str, dict[str, bytes]]:
    if not package.is_file() or package.suffix.lower() != ".zip":
        raise InstallError("package must be an existing ZIP")
    if package.stat().st_size > MAX_ARCHIVE_BYTES:
        raise InstallError("package is too large")
    with zipfile.ZipFile(package) as archive:
        entries: dict[str, bytes] = {}
        for info in archive.infolist():
            name = _relative_name(info.filename.rstrip("/"))
            if not name or name in entries:
                raise InstallError("duplicate or empty archive entry")
            mode = (info.external_attr >> 16) & 0o170000
            if mode == 0o120000:
                raise InstallError("symbolic links are not allowed")
            if not info.is_dir():
                entries[name] = archive.read(info)
        roots = {name.split("/", 1)[0] for name in entries}
        if len(roots) != 1:
            raise InstallError("package must contain one distribution root")
        root = roots.pop()
        _read_checksums(entries, root)
        return root, entries


def _remove_tree(path: Path) -> None:
    if path.exists():
        shutil.rmtree(path)


def _ownership_files(directory: Path) -> set[str]:
    manifest_path = directory / OWNERSHIP_NAME
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        files = manifest["files"]
        if manifest.get("schema_version") != 1 or not isinstance(files, list):
            raise ValueError
        owned = {_relative_name(item) for item in files}
        if len(owned) != len(files) or OWNERSHIP_NAME not in owned:
            raise ValueError
        return owned
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise InstallError(f"invalid ownership manifest: {directory}") from error


def _validate_directory_checksums(directory: Path) -> None:
    checksum_path = directory / "SHA256SUMS.txt"
    if not checksum_path.is_file():
        raise InstallError(f"installed package is missing SHA256SUMS.txt: {directory}")
    try:
        lines = checksum_path.read_text(encoding="utf-8").splitlines()
    except OSError as error:
        raise InstallError("cannot read installed checksums") from error
    listed: set[str] = set()
    for line in lines:
        fields = line.split("  ", 1)
        if len(fields) != 2 or len(fields[0]) != 64 or any(c not in "0123456789abcdef" for c in fields[0]):
            raise InstallError("invalid installed SHA256SUMS.txt entry")
        relative = _relative_name(fields[1])
        target = directory / relative
        if not target.is_file() or _sha256_bytes(target.read_bytes()) != fields[0]:
            raise InstallError(f"installed checksum mismatch: {relative}")
        listed.add(relative)


def install_package(package: Path, destination: Path) -> dict[str, object]:
    """Validate and atomically install *package* into explicit *destination*."""
    root, entries = _read_archive(package.resolve())
    destination = _destination(destination)
    parent = destination.parent
    staging = parent / f".{destination.name}{STAGING_SUFFIX}"
    rollback = parent / f".{destination.name}{ROLLBACK_SUFFIX}"
    if staging.exists():
        raise InstallError(f"staging path already exists: {staging}")
    parent.mkdir(parents=True, exist_ok=True)
    staging.mkdir()
    try:
        preserve: list[Path] = []
        if destination.is_dir():
            manifest_path = destination / OWNERSHIP_NAME
            existing_owned: set[str] = set()
            if manifest_path.is_file():
                try:
                    existing_owned = set(json.loads(manifest_path.read_text(encoding="utf-8"))["files"])
                except (OSError, ValueError, KeyError, TypeError):
                    raise InstallError("existing ownership manifest is invalid")
            for existing in destination.rglob("*"):
                if existing.is_file() and existing.name != OWNERSHIP_NAME:
                    relative = existing.relative_to(destination).as_posix()
                    if relative not in existing_owned:
                        preserve.append(existing)
        owned: list[str] = []
        for name, data in sorted(entries.items()):
            relative = name[len(root) + 1 :]
            target = staging / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            owned.append(relative)
        for existing in preserve:
            relative = existing.relative_to(destination).as_posix()
            target = staging / relative
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(existing, target)
        (staging / OWNERSHIP_NAME).write_text(
            json.dumps({"schema_version": 1, "files": sorted(owned + [OWNERSHIP_NAME])}, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        if rollback.exists():
            _remove_tree(rollback)
        if destination.exists():
            os.replace(destination, rollback)
        try:
            os.replace(staging, destination)
        except OSError:
            if rollback.exists() and not destination.exists():
                os.replace(rollback, destination)
            raise
    except Exception:
        if staging.exists():
            _remove_tree(staging)
        raise
    return {"destination": destination, "rollback": rollback, "files": sorted(owned)}


def uninstall_package(destination: Path) -> dict[str, object]:
    """Remove only files recorded in the package ownership manifest."""
    destination = _destination(destination)
    manifest_path = destination / OWNERSHIP_NAME
    if not manifest_path.is_file():
        raise InstallError("ownership manifest is missing")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        files = manifest["files"]
        if manifest.get("schema_version") != 1 or not isinstance(files, list):
            raise ValueError
        owned = [_relative_name(item) for item in files]
        if len(set(owned)) != len(owned) or OWNERSHIP_NAME not in owned:
            raise ValueError
    except (OSError, ValueError, KeyError, TypeError) as error:
        raise InstallError("invalid ownership manifest") from error
    removed: list[str] = []
    for relative in sorted(owned, key=lambda item: (item.count("/"), item), reverse=True):
        target = destination / relative
        if target.is_file() or target.is_symlink():
            target.unlink()
            removed.append(relative)
    for directory in sorted({(destination / item).parent for item in owned}, key=lambda path: len(path.parts), reverse=True):
        if directory != destination and directory.is_dir():
            try:
                directory.rmdir()
            except OSError:
                pass
    return {"destination": destination, "removed": removed}


def rollback_package(destination: Path) -> dict[str, object]:
    """Atomically make the preserved rollback version current."""
    destination = _destination(destination)
    rollback = destination.parent / f".{destination.name}{ROLLBACK_SUFFIX}"
    staging = destination.parent / f".{destination.name}{STAGING_SUFFIX}"
    if not destination.is_dir() or not rollback.is_dir():
        raise InstallError("current package or rollback version is missing")
    current_owned = _ownership_files(destination)
    rollback_owned = _ownership_files(rollback)
    _validate_directory_checksums(destination)
    _validate_directory_checksums(rollback)
    if staging.exists():
        raise InstallError(f"staging path already exists: {staging}")
    staging.mkdir(parents=True)
    try:
        for source in rollback.rglob("*"):
            relative = source.relative_to(rollback)
            target = staging / relative
            if source.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            elif source.is_file():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
        for source in destination.rglob("*"):
            if not source.is_file():
                continue
            relative = source.relative_to(destination).as_posix()
            if relative not in current_owned:
                target = staging / relative
                if not target.exists():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
        if rollback.exists():
            _remove_tree(rollback)
        os.replace(destination, rollback)
        try:
            os.replace(staging, destination)
        except OSError:
            if not destination.exists() and rollback.exists():
                os.replace(rollback, destination)
            raise
    except Exception:
        if staging.exists():
            _remove_tree(staging)
        raise
    return {"destination": destination, "rollback": rollback, "files": sorted(rollback_owned)}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    install = subparsers.add_parser("install")
    install.add_argument("package", type=Path)
    install.add_argument("destination", type=Path)
    uninstall = subparsers.add_parser("uninstall")
    uninstall.add_argument("destination", type=Path)
    rollback = subparsers.add_parser("rollback")
    rollback.add_argument("destination", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.command == "install":
            result = install_package(args.package, args.destination)
        elif args.command == "rollback":
            result = rollback_package(args.destination)
        else:
            result = uninstall_package(args.destination)
    except (InstallError, OSError, zipfile.BadZipFile) as error:
        print(f"windows-portable-installer: ERROR: {error}")
        return 2
    print(json.dumps({key: str(value) for key, value in result.items()}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
