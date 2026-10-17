#!/usr/bin/env python3
"""Install an existing Linux checkpoint for the current user; never launch it."""
from __future__ import annotations

import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import tarfile
import tempfile
import uuid

MANIFEST = ".mudds-shipyards-install.json"
UPDATE = ".mudds-shipyards-update.json"
UNINSTALL = ".mudds-shipyards-uninstall.json"
DESKTOP = "mudds-shipyards.desktop"
ICON = "mudds-shipyards.png"
BUNDLED_INSTALLER = "install_linux_desktop.py"
OWNER = "mudds-shipyards-linux-desktop"
GENERATION = re.compile(r"\.mudds-shipyards-runtime-[0-9a-f]{32}")
BINARY = re.compile(r"MuddsShipyards-[0-9a-f]{7}\.x86_64")


class InstallError(Exception):
    pass


def safe_path(value: str | Path) -> Path:
    path = Path(os.path.abspath(os.path.expanduser(str(value))))
    if any(ord(c) < 32 or ord(c) == 127 for c in str(path)):
        raise InstallError("directory paths must not contain control characters")
    # Refuse symlinks even in parents, including broken links.
    for part in (path, *path.parents):
        if part.is_symlink():
            raise InstallError(f"refusing symlink path: {part}")
    return path


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def desktop_bytes(runtime: Path, executable: str) -> bytes:
    # Desktop Entry Exec has its own escaping rules, and does not invoke a shell.
    def exec_arg(value: str) -> str:
        value = value.replace("%", "%%")
        for character in ("\\", '"', "`", "$"):
            value = value.replace(character, "\\" + character)
        # The desktop string parser consumes one layer of backslash escaping.
        return '"' + value.replace("\\", "\\\\") + '"'

    def string_value(value: str) -> str:
        return value.replace("\\", "\\\\")

    return (
        "[Desktop Entry]\nType=Application\nName=Mudd's Shipyards\n"
        "Comment=Build, fly and crew your ships\n"
        # Keep the ELF path in an argument: GLib does not expand %% in argv[0].
        f"Exec=/usr/bin/env -- {exec_arg(str(runtime / executable))}\n"
        f"Path={string_value(str(runtime))}\n"
        f"Icon={string_value(str(runtime / ICON))}\n"
        "Terminal=false\nCategories=Game;Simulation;\n"
    ).encode("utf-8")


def atomic_write(path: Path, content: bytes, mode: int = 0o644, *, exclusive: bool = False) -> None:
    fd, name = tempfile.mkstemp(prefix=".mudds-shipyards-pending-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
            os.fchmod(stream.fileno(), mode)
        if exclusive:
            os.link(temporary, path)
        else:
            os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def read_install(install_dir: Path, applications_dir: Path) -> dict | None:
    manifest_path = safe_path(install_dir / MANIFEST)
    desktop = safe_path(applications_dir / DESKTOP)
    if not manifest_path.exists():
        if desktop.exists():
            raise InstallError(f"refusing unrelated desktop entry: {desktop}")
        return None
    if not manifest_path.is_file():
        raise InstallError("installation manifest is not a regular file")
    state = read_state(manifest_path, install_dir, applications_dir)
    runtime = install_dir / state["generation"]
    if not desktop.is_file() or desktop.read_bytes() != desktop_bytes(runtime, state["executable"]):
        raise InstallError(f"owned desktop entry changed or missing: {desktop}")
    return state


def validate_state(state: dict, install_dir: Path, applications_dir: Path,
                   *, allow_missing: bool = False) -> None:
    try:
        if (set(state) != {"owner", "generation", "executable", "applications_dir", "files"}
                or state["owner"] != OWNER
                or not GENERATION.fullmatch(state["generation"])
                or not BINARY.fullmatch(state["executable"])
                or state["applications_dir"] != str(applications_dir)
                or set(state["files"]) != {state["executable"], ICON}
                or any(not re.fullmatch(r"[0-9a-f]{64}", value)
                       for value in state["files"].values())):
            raise ValueError("invalid ownership fields or applications directory")
    except (ValueError, TypeError, KeyError, AttributeError) as error:
        raise InstallError(f"invalid installation manifest: {error}") from error
    runtime = safe_path(install_dir / state["generation"])
    if runtime.exists() and not runtime.is_dir():
        raise InstallError(f"owned runtime is not a directory: {runtime}")
    for name, expected in state["files"].items():
        path = safe_path(runtime / name)
        if allow_missing and not path.exists():
            continue
        if not path.is_file() or digest(path) != expected:
            raise InstallError(f"owned file changed or missing; refusing mutation: {path}")


def read_state(path: Path, install_dir: Path, applications_dir: Path,
               *, allow_missing: bool = False) -> dict:
    if not path.is_file():
        raise InstallError("installation manifest is not a regular file")
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except ValueError as error:
        raise InstallError(f"invalid installation manifest: {error}") from error
    validate_state(state, install_dir, applications_dir, allow_missing=allow_missing)
    return state


def refuse_pending_uninstall(install_dir: Path) -> None:
    if safe_path(install_dir / UNINSTALL).exists():
        raise InstallError("pending uninstall recovery record; retry uninstall first")


def read_uninstall(install_dir: Path, applications_dir: Path) -> dict | None:
    """Validate the complete removal intent before deleting any surviving file."""
    path = safe_path(install_dir / UNINSTALL)
    if not path.exists():
        return None
    if not path.is_file():
        raise InstallError("uninstall recovery record is not a regular file")
    try:
        removal = json.loads(path.read_text(encoding="utf-8"))
        if set(removal) != {"owner", "state"} or removal["owner"] != OWNER:
            raise ValueError("invalid uninstall ownership fields")
        state = removal["state"]
        validate_state(state, install_dir, applications_dir, allow_missing=True)
    except (ValueError, TypeError, KeyError, AttributeError) as error:
        raise InstallError(f"invalid uninstall recovery record: {error}") from error
    manifest = safe_path(install_dir / MANIFEST)
    desktop = safe_path(applications_dir / DESKTOP)
    if manifest.exists():
        current = read_state(manifest, install_dir, applications_dir, allow_missing=True)
        if current != state:
            raise InstallError("installation manifest differs from uninstall recovery record")
    elif desktop.exists() or any((install_dir / state["generation"] / name).exists()
                                 for name in state["files"]):
        # The manifest is retired only after the launcher and all owned payloads.
        raise InstallError("installation manifest missing before uninstall completed")
    if desktop.exists() and (not desktop.is_file() or desktop.read_bytes() != desktop_bytes(
            install_dir / state["generation"], state["executable"])):
        raise InstallError(f"owned desktop entry changed: {desktop}")
    return state


def read_update(install_dir: Path, applications_dir: Path) -> tuple[dict | None, dict, dict | None] | None:
    """Validate an interrupted install/update before allowing any recovery write."""
    path = safe_path(install_dir / UPDATE)
    if not path.exists():
        return None
    if not path.is_file():
        raise InstallError("update recovery record is not a regular file")
    try:
        update = json.loads(path.read_text(encoding="utf-8"))
        if set(update) != {"owner", "previous", "pending"} or update["owner"] != OWNER:
            raise ValueError("invalid update ownership fields")
        previous, pending = update["previous"], update["pending"]
        if previous is not None:
            validate_state(previous, install_dir, applications_dir)
        validate_state(pending, install_dir, applications_dir)
        if previous is not None and previous["generation"] == pending["generation"]:
            raise ValueError("update generations must differ")
    except (ValueError, TypeError, KeyError, AttributeError) as error:
        raise InstallError(f"invalid update recovery record: {error}") from error
    manifest = safe_path(install_dir / MANIFEST)
    current = (None if previous is None and not manifest.exists()
               else read_state(manifest, install_dir, applications_dir))
    if current not in (previous, pending):
        raise InstallError("installation manifest differs from update recovery record")
    desktop = safe_path(applications_dir / DESKTOP)
    # An initial transaction may die before publishing any launcher. Once one
    # exists, only exact journal-owned bytes qualify; arbitrary entries are refused.
    if previous is None and current is None and not desktop.exists():
        return previous, pending, current
    # A committed new manifest must have its new launcher. Before that commit,
    # either exact launcher is ours; arbitrary edits are still refused.
    allowed = (previous, pending) if previous is not None and current == previous else (pending,)
    if not desktop.is_file() or desktop.read_bytes() not in tuple(
            desktop_bytes(install_dir / state["generation"], state["executable"])
            for state in allowed):
        raise InstallError(f"owned desktop entry changed or missing: {desktop}")
    return previous, pending, current


def recover_update(install_dir: Path, applications_dir: Path) -> None:
    # Called only under installation_lock. This journal covers process death
    # during installs and updates. Power-loss durability is not established.
    update = read_update(install_dir, applications_dir)
    if update is None:
        return
    previous, pending, current = update
    if current == previous:
        if previous is None:
            (applications_dir / DESKTOP).unlink(missing_ok=True)
        else:
            atomic_write(applications_dir / DESKTOP,
                         desktop_bytes(install_dir / previous["generation"], previous["executable"]))
    # Retire the journal before cleanup so interrupted cleanup cannot leave a
    # journal referring to partly removed payloads. Untracked files survive.
    (install_dir / UPDATE).unlink()
    obsolete = pending if current == previous else previous
    if obsolete is not None:
        remove_payload(install_dir, obsolete)


@contextlib.contextmanager
def checked_archive(path: Path):
    """Validate every member and gzip checksum before creating installation files."""
    with tarfile.open(path, "r:gz") as archive:
        members = []
        seen = set()
        for member in archive:
            members.append(member)
            if len(members) > 6:
                raise InstallError("archive must contain five or six standard checkpoint members")
            if member.name in seen:
                raise InstallError(f"duplicate archive member: {member.name}")
            seen.add(member.name)
            parts = PurePosixPath(member.name).parts
            if (member.name.startswith("/") or ".." in parts
                    or not (member.isdir() or member.isfile())
                    or member.mode & 0o7000):
                raise InstallError(f"unsafe archive member: {member.name}")
        roots = [member for member in members if member.isdir()]
        if len(roots) != 1 or not re.fullmatch(r"MuddsShipyards-[0-9a-f]{7}", roots[0].name.rstrip("/")):
            raise InstallError("archive must have one standard checkpoint directory")
        root = roots[0].name.rstrip("/")
        executable = root + ".x86_64"
        names = {f"{root}/{name}" for name in (executable, ICON, DESKTOP, "install-desktop-entry.sh")}
        files = [member for member in members if member.isfile()]
        file_names = {member.name for member in files}
        if file_names not in (names, names | {f"{root}/{BUNDLED_INSTALLER}"}):
            raise InstallError("archive contents differ from the standard checkpoint bundle")
        for member in files:
            limit = 2 * 1024**3 if member.name.endswith(".x86_64") else 16 * 1024**2
            if not 0 < member.size <= limit:
                raise InstallError(f"invalid archive member size: {member.name}")
            if member.name.endswith(".x86_64") and not member.mode & 0o111:
                raise InstallError("archived game is not executable")
        # tar's end marker alone does not establish a complete gzip stream.
        archive.fileobj.seek(0, os.SEEK_END)
        for name, magic in ((executable, b"\x7fELF"), (ICON, b"\x89PNG\r\n\x1a\n")):
            with archive.extractfile(f"{root}/{name}") as stream:
                if stream.read(len(magic)) != magic:
                    raise InstallError(f"invalid {name} file header")
        yield archive, root, executable


def remove_payload(install_dir: Path, state: dict, *, allow_missing: bool = False) -> None:
    runtime = install_dir / state["generation"]
    for name in state["files"]:
        (runtime / name).unlink(missing_ok=allow_missing)
    # Untracked files (including a user-created profile) are never removed.
    try:
        runtime.rmdir()
    except OSError:
        pass


@contextlib.contextmanager
def installation_lock(install_dir: Path):
    # Linux flock on the directory avoids leaving an unowned lock file behind.
    fd = os.open(install_dir, os.O_RDONLY | os.O_DIRECTORY)
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)
        yield
    finally:
        os.close(fd)


def install(archive_path: Path, install_dir: Path, applications_dir: Path) -> None:
    install_dir, applications_dir = safe_path(install_dir), safe_path(applications_dir)
    # Archive and destination refusal happen before any directory is created.
    refuse_pending_uninstall(install_dir)
    with checked_archive(archive_path) as (archive, root, executable):
        if read_update(install_dir, applications_dir) is None:
            read_install(install_dir, applications_dir)
        install_dir.mkdir(parents=True, exist_ok=True)
        applications_dir.mkdir(parents=True, exist_ok=True)
        with installation_lock(install_dir):
            refuse_pending_uninstall(install_dir)
            recover_update(install_dir, applications_dir)
            previous = read_install(install_dir, applications_dir)
            generation = ".mudds-shipyards-runtime-" + uuid.uuid4().hex
            runtime = install_dir / generation
            runtime.mkdir(mode=0o755)
            desktop = applications_dir / DESKTOP
            old_desktop = desktop.read_bytes() if previous else None
            published = False
            journaled = False
            try:
                for name in (executable, ICON):
                    with archive.extractfile(f"{root}/{name}") as source, (runtime / name).open("xb") as target:
                        shutil.copyfileobj(source, target)
                        target.flush()
                        os.fsync(target.fileno())
                    (runtime / name).chmod(0o755 if name == executable else 0o644)
                state = {
                    "owner": OWNER, "generation": generation, "executable": executable,
                    "applications_dir": str(applications_dir),
                    "files": {name: digest(runtime / name) for name in (executable, ICON)},
                }
                update = {"owner": OWNER, "previous": previous, "pending": state}
                atomic_write(install_dir / UPDATE,
                             (json.dumps(update, indent=2) + "\n").encode(), exclusive=True)
                journaled = True
                atomic_write(desktop, desktop_bytes(runtime, executable), exclusive=previous is None)
                published = True
                atomic_write(install_dir / MANIFEST, (json.dumps(state, indent=2) + "\n").encode())
            except BaseException:
                if published:
                    if old_desktop is None:
                        desktop.unlink()
                    else:
                        atomic_write(desktop, old_desktop)
                if journaled:
                    (install_dir / UPDATE).unlink()
                for name in (executable, ICON):
                    (runtime / name).unlink(missing_ok=True)
                runtime.rmdir()
                raise
            (install_dir / UPDATE).unlink()
            if previous:
                remove_payload(install_dir, previous)


def uninstall(install_dir: Path, applications_dir: Path) -> None:
    install_dir, applications_dir = safe_path(install_dir), safe_path(applications_dir)
    if not install_dir.exists():
        # Never remove an entry without an ownership manifest.
        if (applications_dir / DESKTOP).exists():
            raise InstallError("desktop entry has no installation ownership manifest")
        return
    with installation_lock(install_dir):
        if safe_path(install_dir / UPDATE).exists():
            raise InstallError("pending install/update recovery record; retry install first")
        state = read_uninstall(install_dir, applications_dir)
        if state is None:
            state = read_install(install_dir, applications_dir)
            if state is None:
                return
            removal = {"owner": OWNER, "state": state}
            # Commit intent before removing the launcher, so a new process can
            # distinguish our interrupted removal from a missing/foreign entry.
            atomic_write(install_dir / UNINSTALL,
                         (json.dumps(removal, indent=2) + "\n").encode(), exclusive=True)
        (applications_dir / DESKTOP).unlink(missing_ok=True)
        remove_payload(install_dir, state, allow_missing=True)
        (install_dir / MANIFEST).unlink(missing_ok=True)
        (install_dir / UNINSTALL).unlink()
    try:
        install_dir.rmdir()
    except OSError:
        pass


def main(argv: list[str] | None = None) -> int:
    data_home = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ("install", "uninstall"):
        subparser = commands.add_parser(command)
        if command == "install":
            subparser.add_argument("--archive", type=Path, required=True)
        subparser.add_argument("--install-dir", type=Path, default=data_home / "mudds-shipyards")
        subparser.add_argument("--applications-dir", type=Path, default=data_home / "applications")
    args = parser.parse_args(argv)
    try:
        if not data_home.is_absolute():
            raise InstallError("XDG_DATA_HOME must be absolute")
        if args.command == "install":
            install(args.archive, args.install_dir, args.applications_dir)
        else:
            uninstall(args.install_dir, args.applications_dir)
    except (InstallError, OSError, tarfile.TarError, EOFError) as error:
        parser.exit(1, f"linux-desktop-install: {error}\n")
    print(f"{args.command}: {safe_path(args.install_dir)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
