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
import re
from pathlib import Path, PurePosixPath


OWNERSHIP_NAME = ".mudds-owned.json"
ROLLBACK_SUFFIX = ".rollback"
STAGING_SUFFIX = ".staging"
LAUNCHER_NAME = "Start Mudds Shipyards.cmd"
LAUNCHER_EXE = "MuddsShipyards.exe"
MAX_ARCHIVE_BYTES = 512 * 1024 * 1024
VERSION_RE = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$")


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


def _sha256_file(path: Path) -> str:
    return _sha256_bytes(path.read_bytes())


def _launcher_bytes() -> bytes:
    """Return a safe launcher that resolves the bundled EXE beside itself."""
    return (
        "@echo off\r\n"
        "setlocal\r\n"
        f'"%~dp0{LAUNCHER_EXE}" %*\r\n'
    ).encode("ascii")


def _version_key(version: str) -> tuple[tuple[int, int, int], tuple[tuple[int, object], ...]]:
    match = VERSION_RE.fullmatch(version)
    if not match:
        raise InstallError(f"invalid distribution version: {version!r}")
    base = tuple(int(match.group(index)) for index in range(1, 4))
    prerelease = match.group(4)
    if prerelease is None:
        return base, ((1, ""),)
    parts: list[tuple[int, object]] = [(0, "")]
    for part in prerelease.split("."):
        parts.append((0, int(part)) if part.isdigit() else (1, part))
    return base, tuple(parts)


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


def _archive_metadata(entries: dict[str, bytes], root: str) -> tuple[str, str]:
    try:
        manifest = json.loads(entries[f"{root}/distribution-manifest.json"].decode("utf-8"))
        version = str(manifest["version"])
        source_commit = str(manifest["source_commit"])
        _version_key(version)
        if not re.fullmatch(r"[0-9a-f]{40,64}", source_commit):
            raise ValueError
        return version, source_commit
    except (KeyError, TypeError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise InstallError("distribution-manifest metadata is invalid") from error


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


def install_package(package: Path, destination: Path, *, force: bool = False) -> dict[str, object]:
    """Validate and atomically install *package* into explicit *destination*."""
    package = package.resolve()
    root, entries = _read_archive(package)
    version, source_commit = _archive_metadata(entries, root)
    package_sha256 = _sha256_file(package)
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
                    current_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                    existing_owned = set(current_manifest["files"])
                    current_version = str(current_manifest["version"])
                    if not force and _version_key(version) < _version_key(current_version):
                        raise InstallError("downgrade requires force=True")
                    if not force and _version_key(version) == _version_key(current_version):
                        if current_manifest.get("package_sha256") == package_sha256:
                            return {"destination": destination, "reason": "already_installed", "files": []}
                        raise InstallError("same-version replacement requires force=True")
                except InstallError:
                    raise
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
        launcher = staging / LAUNCHER_NAME
        launcher.write_bytes(_launcher_bytes())
        owned.append(LAUNCHER_NAME)
        for existing in preserve:
            relative = existing.relative_to(destination).as_posix()
            target = staging / relative
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(existing, target)
        (staging / OWNERSHIP_NAME).write_text(
            json.dumps({
                "schema_version": 1,
                "version": version,
                "source_commit": source_commit,
                "package_sha256": package_sha256,
                "files": sorted(owned + [OWNERSHIP_NAME]),
            }, sort_keys=True) + "\n",
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


def package_status(destination: Path) -> dict[str, object]:
    destination = _destination(destination)
    if not destination.is_dir():
        raise InstallError("installed package is missing")
    manifest = json.loads((destination / OWNERSHIP_NAME).read_text(encoding="utf-8"))
    _ownership_files(destination)
    _validate_directory_checksums(destination)
    rollback = destination.parent / f".{destination.name}{ROLLBACK_SUFFIX}"
    rollback_status: dict[str, object] = {"present": rollback.is_dir()}
    if rollback.is_dir():
        rollback_manifest = json.loads((rollback / OWNERSHIP_NAME).read_text(encoding="utf-8"))
        _ownership_files(rollback)
        _validate_directory_checksums(rollback)
        rollback_status.update({"version": rollback_manifest.get("version"), "valid": True})
    return {
        "destination": destination,
        "version": manifest.get("version"),
        "source_commit": manifest.get("source_commit"),
        "owned_file_count": len(_ownership_files(destination)),
        "rollback": rollback_status,
    }


def recover_install(destination: Path, action: str = "status") -> dict[str, object]:
    """Inspect or explicitly resume/discard a fixed-path install transaction."""
    destination = _destination(destination)
    staging = destination.parent / f".{destination.name}{STAGING_SUFFIX}"
    rollback = destination.parent / f".{destination.name}{ROLLBACK_SUFFIX}"
    if action not in {"status", "resume", "discard"}:
        raise InstallError("recovery action must be status, resume, or discard")
    if action == "status":
        return {
            "destination": destination,
            "staging_present": staging.is_dir(),
            "rollback_present": rollback.is_dir(),
            "resume_available": staging.is_dir() and not destination.exists() or rollback.is_dir() and not destination.exists(),
        }
    if action == "discard":
        if not staging.exists():
            return {"destination": destination, "reason": "no_staging"}
        if not staging.is_dir():
            raise InstallError("staging path is not a directory")
        _ownership_files(staging)
        _validate_directory_checksums(staging)
        _remove_tree(staging)
        return {"destination": destination, "reason": "staging_discarded"}
    if destination.exists():
        raise InstallError("destination is present; resume would overwrite it")
    if staging.is_dir():
        _ownership_files(staging)
        _validate_directory_checksums(staging)
        os.replace(staging, destination)
        return {"destination": destination, "reason": "staging_resumed"}
    if rollback.is_dir():
        _ownership_files(rollback)
        _validate_directory_checksums(rollback)
        os.replace(rollback, destination)
        return {"destination": destination, "reason": "rollback_restored"}
    raise InstallError("no recoverable staging or rollback artifact")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    install = subparsers.add_parser("install")
    install.add_argument("package", type=Path)
    install.add_argument("destination", type=Path)
    install.add_argument("--force", action="store_true")
    install.add_argument("--dry-run", action="store_true")
    upgrade = subparsers.add_parser("upgrade")
    upgrade.add_argument("package", type=Path)
    upgrade.add_argument("destination", type=Path)
    upgrade.add_argument("--force", action="store_true")
    upgrade.add_argument("--dry-run", action="store_true")
    uninstall = subparsers.add_parser("uninstall")
    uninstall.add_argument("destination", type=Path)
    uninstall.add_argument("--dry-run", action="store_true")
    rollback = subparsers.add_parser("rollback")
    rollback.add_argument("destination", type=Path)
    rollback.add_argument("--dry-run", action="store_true")
    status = subparsers.add_parser("status")
    status.add_argument("destination", type=Path)
    recover = subparsers.add_parser("recover")
    recover.add_argument("destination", type=Path)
    recover.add_argument("action", choices=["status", "resume", "discard"])
    args = parser.parse_args(argv)
    try:
        if args.command == "install":
            if args.dry_run:
                root, entries = _read_archive(args.package.resolve())
                version, source_commit = _archive_metadata(entries, root)
                destination = _destination(args.destination)
                manifest_path = destination / OWNERSHIP_NAME
                if destination.exists() and manifest_path.is_file() and not args.force:
                    current = json.loads(manifest_path.read_text(encoding="utf-8"))
                    if _version_key(version) < _version_key(str(current["version"])):
                        raise InstallError("downgrade requires force=True")
                    if _version_key(version) == _version_key(str(current["version"])):
                        if current.get("package_sha256") != _sha256_file(args.package.resolve()):
                            raise InstallError("same-version replacement requires force=True")
                result = {"action": "install", "dry_run": True, "version": version, "source_commit": source_commit, "destination": destination}
            elif _destination(args.destination).exists():
                raise InstallError("destination exists; use upgrade")
            else:
                result = install_package(args.package, args.destination, force=args.force)
        elif args.command == "upgrade":
            if not _destination(args.destination).exists():
                raise InstallError("upgrade destination is missing")
            if args.dry_run:
                root, entries = _read_archive(args.package.resolve())
                version, source_commit = _archive_metadata(entries, root)
                destination = _destination(args.destination)
                if not args.force:
                    current = json.loads((destination / OWNERSHIP_NAME).read_text(encoding="utf-8"))
                    if _version_key(version) < _version_key(str(current["version"])):
                        raise InstallError("downgrade requires force=True")
                    if _version_key(version) == _version_key(str(current["version"])):
                        if current.get("package_sha256") != _sha256_file(args.package.resolve()):
                            raise InstallError("same-version replacement requires force=True")
                result = {"action": "upgrade", "dry_run": True, "version": version, "source_commit": source_commit, "destination": destination}
            else:
                result = install_package(args.package, args.destination, force=args.force)
        elif args.command == "status":
            result = package_status(args.destination)
        elif args.command == "recover":
            result = recover_install(args.destination, args.action)
        elif args.command == "rollback":
            if args.dry_run:
                result = package_status(args.destination)
                result["action"] = "rollback"
                result["dry_run"] = True
            else:
                result = rollback_package(args.destination)
        else:
            if args.dry_run:
                destination = _destination(args.destination)
                owned = sorted(_ownership_files(destination))
                result = {"action": "uninstall", "dry_run": True, "destination": destination, "would_remove": owned}
            else:
                result = uninstall_package(args.destination)
    except (InstallError, OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"windows-portable-installer: ERROR: {error}")
        return 2
    print(json.dumps({key: str(value) for key, value in result.items()}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
