#!/usr/bin/env python3
"""Opt-in, isolated Godot 4.7.1 editor build for the reflection-atlas fix.

Default: print the plan, without writes or network access.
--prepare: verify/download official source and pinned SCons; do not apply/build.
--build: prepare, apply the reviewed guarded patch, and compile (max 4 jobs).

Output is a custom editor for explicit GODOT_BIN use, never an installation or
an export template. This recipe pins inputs/options, not host compiler binaries.
"""

import argparse
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import shutil
import signal
import subprocess
import sys
import tarfile
import time
import urllib.request
import venv


CACHE = Path.home() / ".cache/mudds-shipyards/godot-4.7.1-reflection-atlas"
SOURCE_NAME = "godot-4.7.1-stable"
SOURCE_SHA = "0230d490846467c4fd772cc70b08dc56cb3adfedd55d039de0af74ddfdba00eb"
SOURCE_URL = (
    "https://github.com/godotengine/godot-builds/releases/download/4.7.1-stable/"
    + SOURCE_NAME + ".tar.xz"
)
SOURCE_COMMIT = "a13da4feb8d8aefc283c3763d33a2f170a18d541"
WHEEL_NAME = "scons-4.10.1-py3-none-any.whl"
WHEEL_SHA = "bd9d1c52f908d874eba92a8c0c0a8dcf2ed9f3b88ab956d0fce1da479c4e7126"
WHEEL_URL = (
    "https://files.pythonhosted.org/packages/ce/bf/"
    "931fb9fbb87234c32b8b1b1c15fba23472a10777c12043336675633809a7/" + WHEEL_NAME
)
PATCH = Path(__file__).resolve().parent / "patches/godot-4.7.1-reflection-atlas.patch"
PATCH_SHA = "fcc946bc8b55e5afff50db6e7dcf97ed0f767bfddea6e7e86ceb7fe0c75c5cef"
TARGET = "servers/rendering/renderer_rd/storage_rd/light_storage.cpp"
BEFORE_SHA = "b5619355dddef39ddc9a6277786e0cbf3dc1696c57ffb7dcd35df8fcb165e96c"
AFTER_SHA = "eb1b28b095f0c72027f6c8adfaaa145577c0f26bebc0808734f27cbcde11bfda"
BUILD_NAME = "mudds_reflection_atlas_a2917e5_guarded"
SUFFIX = "mudds_reflection_atlas"
OPTIONS = [
    "platform=linuxbsd", "target=editor", "arch=x86_64", "use_llvm=no",
    "precision=single", "dev_build=no", "debug_symbols=no", "optimize=speed",
    "lto=none", "extra_suffix=" + SUFFIX,
]


class Cancelled(Exception):
    pass


def install_cancellation():
    def terminate(_signal, _frame):
        raise Cancelled("terminated by SIGTERM")
    signal.signal(signal.SIGTERM, terminate)
    # Adopt orphaned compiler grandchildren so abort cleanup can reap them.
    require(ctypes.CDLL(None, use_errno=True).prctl(36, 1, 0, 0, 0) == 0,
            "Cannot enable Linux child subreaper")


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def download(url, path, expected):
    if not path.exists():
        partial = path.with_name(path.name + ".part")
        # Preserve an interrupted download for inspection; never silently resume it.
        with partial.open("xb") as output, urllib.request.urlopen(url, timeout=60) as response:
            shutil.copyfileobj(response, output)
        require(sha(partial) == expected, "Download SHA mismatch: " + str(partial))
        partial.rename(path)
    require(not path.is_symlink() and sha(path) == expected, "Input SHA mismatch: " + str(path))


def source_tree(archive, source):
    """Reject unsafe members; verify shipped source on every reuse."""
    with tarfile.open(archive, "r:xz") as tar:
        members = tar.getmembers()
        names = set()
        for member in members:
            name = PurePosixPath(member.name)
            require(not name.is_absolute() and ".." not in name.parts, "Unsafe archive path")
            require(name.parts[0] == SOURCE_NAME, "Unexpected archive root")
            require(member.isdir() or member.isfile(), "Archive links/devices are forbidden")
            require(member.name not in names, "Duplicate archive member")
            names.add(member.name)
        if not source.exists():
            tar.extractall(CACHE, members=members, filter="data")
        require(source.is_dir() and not source.is_symlink(), "Invalid source directory")
        for member in members:
            if not member.isfile():
                continue
            relative = PurePosixPath(member.name).relative_to(SOURCE_NAME)
            path = source / str(relative)
            require(not path.is_symlink(), "Source symlink: " + str(path))
            if str(relative) == TARGET:
                require(sha(path) in (BEFORE_SHA, AFTER_SHA), "Unexpected patch target bytes")
            else:
                with tar.extractfile(member) as stream:
                    expected = hashlib.file_digest(stream, "sha256").hexdigest()
                require(sha(path) == expected, "Changed shipped source: " + str(relative))


def session_actors(session):
    remaining = []
    for stat in Path("/proc").glob("[0-9]*/stat"):
        try:
            raw = stat.read_text()
            fields = raw[raw.rfind(")") + 2:].split()
            if int(fields[3]) == session:
                remaining.append((stat.parent.name, fields[19]))
        except (FileNotFoundError, ProcessLookupError):
            pass
    return remaining


def close_session(process):
    # Ignore a second cancellation while closing our own process group.
    previous = {sig: signal.signal(sig, signal.SIG_IGN) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        for sig, grace in ((signal.SIGTERM, 10), (signal.SIGKILL, 5)):
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                pass
            deadline = time.monotonic() + grace
            while time.monotonic() < deadline:
                process.poll()  # Reap the direct child first.
                try:
                    while os.waitpid(-process.pid, os.WNOHANG)[0]:
                        pass  # Reap adopted descendants from this group only.
                except ChildProcessError:
                    pass
                if not session_actors(process.pid):
                    process.wait()
                    return
                time.sleep(0.05)
        raise RuntimeError(f"Owned session did not close: {session_actors(process.pid)}")
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def run(command, env, cwd, log, timeout):
    started = time.monotonic()
    with log.open("ab") as output:
        output.write(("\nCOMMAND " + repr(command) + "\n").encode())
        output.flush()
        process = subprocess.Popen(command, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
                                   stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        raw = Path(f"/proc/{process.pid}/stat").read_text()
        start_tick = raw[raw.rfind(")") + 2:].split()[19]
        print(f"RUNNING pid={process.pid} start_ticks={start_tick} log={log}", flush=True)
        try:
            code = process.wait(timeout=timeout)
            require(code == 0, f"Command failed ({code}); see {log}")
        except BaseException:
            close_session(process)
            raise
    remaining = session_actors(process.pid)
    if remaining:
        close_session(process)
    require(not remaining, f"Owned session actors remain: {remaining}")
    return {"command": command, "exit": code, "pid": process.pid,
            "start_ticks": start_tick, "seconds": round(time.monotonic() - started, 3)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--prepare", action="store_true")
    action.add_argument("--build", action="store_true")
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=2)
    parser.add_argument("--timeout", type=int, default=3600, help="Compile wall cap, at most 3600s")
    args = parser.parse_args()
    require(0 < args.timeout <= 3600, "Compile timeout must be 1..3600 seconds")
    source = CACHE / SOURCE_NAME
    binary = source / ("bin/godot.linuxbsd.editor.x86_64." + SUFFIX)
    plan = {"source_commit": SOURCE_COMMIT, "source_url": SOURCE_URL, "source_sha256": SOURCE_SHA,
            "patch": str(PATCH), "patch_sha256": PATCH_SHA, "scons_version": "4.10.1",
            "scons_wheel_sha256": WHEEL_SHA, "cache": str(CACHE), "binary": str(binary),
            "custom_build_name": BUILD_NAME, "options": OPTIONS, "jobs": args.jobs,
            "compile_timeout": args.timeout, "default_engine_templates_changed": False}
    print(json.dumps(plan, indent=2), flush=True)
    if not (args.prepare or args.build):
        return
    install_cancellation()
    require(sys.platform == "linux" and platform.machine() == "x86_64", "Linux x86_64 only")
    for tool in ("gcc", "g++", "ar", "pkg-config", "patch"):
        require(shutil.which(tool), "Missing build dependency: " + tool)
    require(sha(PATCH) == PATCH_SHA, "Reviewed patch bytes changed")
    os.umask(0o077)
    CACHE.mkdir(mode=0o700, parents=True, exist_ok=True)
    CACHE.chmod(0o700)
    with (CACHE / "build.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        env = os.environ.copy()  # HOME remains inherited.
        for key in ("DISPLAY", "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "XAUTHORITY", "PYTHONPATH", "PYTHONHOME"):
            env.pop(key, None)
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME",
                    "XDG_RUNTIME_DIR", "XDG_DATA_DIRS", "XDG_CONFIG_DIRS", "TMPDIR"):
            path = CACHE / "profile" / key.lower()
            path.mkdir(mode=0o700, parents=True, exist_ok=True)
            path.chmod(0o700)
            env[key] = str(path)
        env.update(PYTHONDONTWRITEBYTECODE="1", PYTHONNOUSERSITE="1", PIP_CONFIG_FILE=os.devnull,
                   GIT_OPTIONAL_LOCKS="0", BUILD_NAME=BUILD_NAME, SOURCE_DATE_EPOCH="0")
        archive = CACHE / (SOURCE_NAME + ".tar.xz")
        download(SOURCE_URL, archive, SOURCE_SHA)
        source_tree(archive, source)
        wheel = CACHE / WHEEL_NAME
        download(WHEEL_URL, wheel, WHEEL_SHA)
        python = CACHE / "venv/bin/python"
        if not python.exists():
            venv.EnvBuilder(with_pip=True).create(CACHE / "venv")
        log = CACHE / "build.log"
        rows = [run([str(python), "-m", "pip", "install", "--no-index", "--no-deps",
                     "--disable-pip-version-check", str(wheel)], env, CACHE, log, 120)]
        if not args.build:
            print("PREPARED; patch unapplied unless already built; no compilation", flush=True)
            return
        if sha(source / TARGET) == BEFORE_SHA:
            rows.append(run(["patch", "--batch", "--forward", "--fuzz=0", "-p1", "-i", str(PATCH)],
                            env, source, log, 30))
        require(sha(source / TARGET) == AFTER_SHA, "Patched target SHA mismatch")
        rows.append(run([str(python), "-m", "SCons", f"-j{args.jobs}", *OPTIONS],
                        env, source, log, args.timeout))
        require(binary.is_file(), "Expected editor binary missing")
        with binary.open("rb") as stream:
            require(stream.read(4) == b"\x7fELF", "Expected editor ELF missing")
        rows.append(run([str(binary), "--headless", "--audio-driver", "Dummy", "--version"],
                        env, CACHE, log, 30))
        source_tree(archive, source)
        plan.update(binary_sha256=sha(binary), binary_bytes=binary.stat().st_size, commands=rows,
                    purpose="Explicit GODOT_BIN for station traversal/ReflectionProbe validation; not qualified")
        (CACHE / "build-result.json").write_text(json.dumps(plan, indent=2) + "\n")
        print(f"BUILT {binary}\nSHA256 {plan['binary_sha256']}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except Cancelled as error:
        print(f"build-godot-reflection-fix: {error}", file=sys.stderr)
        sys.exit(143)
    except KeyboardInterrupt:
        print("build-godot-reflection-fix: interrupted", file=sys.stderr)
        sys.exit(130)
    except (OSError, RuntimeError, subprocess.SubprocessError, tarfile.TarError) as error:
        print(f"build-godot-reflection-fix: {error}", file=sys.stderr)
        sys.exit(1)
