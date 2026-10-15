#!/usr/bin/env python3
"""Opt-in, isolated Godot 4.7.1 build for the reflection-atlas fix.

Default: print the plan, without writes or network access.
--prepare: verify/download official source and pinned SCons; do not apply/build.
--build: prepare, apply the reviewed guarded patch, and compile (max 4 jobs).
--target: editor (default) or template_release for private Linux release exports.
--mesh-content-revision: opt in to the separate RD mesh revision feature build.
--retained-probe-lifecycle: cancel pending probe capture on scenario detach.

Neither target changes installed engines/templates. This recipe pins inputs and
options, not host compiler binaries. Template results stay separate from editor
results; GODOT_BIN alone selects the exporting editor, not the packaged runtime.
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
MESH_PATCH = PATCH.with_name("godot-4.7.1-mesh-content-revision.patch")
MESH_PATCH_SHA = "8f8669557317a9abce99062c5483f4ba1961ddbecea6645fbe2beb509ad85ba9"
MESH_SUFFIX = SUFFIX + "_mesh_revision"
MESH_BUILD_NAME = BUILD_NAME + "_mesh_revision"
# Original and reviewed patched bytes; unsupported modes reject these changes.
MESH_TARGETS = {
    "servers/rendering/rendering_server.h": (
        "5e0e9b836f0c2e41c7237c0a72b76c5d60f632bd8294294a5f28ff1b975c2cd8",
        "262c70bb1273babf5a5d449b6e93f823baafaf813741f00283d5c91dcf2321c4"),
    "servers/rendering/rendering_server.cpp": (
        "b108f62d9d6113061dd1261e7bef51515fbdba9080b4393245e84cecc67ad7ca",
        "5a6516dc446a7ab6e4e3622b9dcb68d1dbddf0e783e432242b5bbc140ac151ab"),
    "servers/rendering/rendering_server_default.h": (
        "eff3cdd80dcfdb7643d5651f3a96fac12011414e4d5f8ecb3645638dfb43481b",
        "d1072c77f467f4edc8bfacb0ae83bed0a6527b797e129ad3f7eb3a665494ef31"),
    "servers/rendering/storage/mesh_storage.h": (
        "4a0e0f91b33770cbb9ebed127f78725fb8811fc6ead1e5fff45b31858f96df17",
        "e846f576b07e416f9dcabf8f4658a5c1fd6144e0d8419df69c4bb2f62e26fc55"),
    "servers/rendering/renderer_rd/storage_rd/mesh_storage.h": (
        "9ae96a7d399d3f2ae1fdca43f1817bb3676fe6eeb5b189dacdedbc5f8725b660",
        "1e0f659ffbf3fd42b5aa22a63be23881c66b33622a37d73001d4cd635133834b"),
    "servers/rendering/renderer_rd/storage_rd/mesh_storage.cpp": (
        "d610f7f4b89ab4b10b038fabf3522bd9497add4fd9438ea5770597a6857a3bad",
        "a3c6e47f3ad2d7bd21ff1c924dd9c9f27467260391fb8c35f567e1b3fdabeca8"),
}

PROBE_PATCH = PATCH.with_name("godot-4.7.1-retained-probe-lifecycle.patch")
PROBE_PATCH_SHA = "0bd2ecfbce331baf2f5fd7fbfd1bb085d1c1271e83f14bbc37e7e30d10368aea"
PROBE_TARGET = "servers/rendering/renderer_scene_cull.cpp"
PROBE_BEFORE_SHA = "80f0761682f6df8abe683f843f6fc8fd1fc9a646783298491d597f2634b5e810"
PROBE_AFTER_SHA = "811f5b85bf66e05b8dc755d4257cc7934c7760491f2c7d78ad27e413ecd243fa"


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


def source_tree(archive, source, mesh_content_revision=False, retained_probe_lifecycle=False):
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
            elif mesh_content_revision and str(relative) in MESH_TARGETS:
                require(sha(path) in MESH_TARGETS[str(relative)], "Unexpected mesh revision target bytes")
            elif retained_probe_lifecycle and str(relative) == PROBE_TARGET:
                require(sha(path) in (PROBE_BEFORE_SHA, PROBE_AFTER_SHA),
                        "Unexpected retained probe target bytes")
            else:
                with tar.extractfile(member) as stream:
                    expected = hashlib.file_digest(stream, "sha256").hexdigest()
                require(sha(path) == expected, "Changed shipped source: " + str(relative))


def apply_mesh_patch(source, env, log):
    before = all(sha(source / name) == hashes[0] for name, hashes in MESH_TARGETS.items())
    after = all(sha(source / name) == hashes[1] for name, hashes in MESH_TARGETS.items())
    require(before or after, "Mixed or unexpected mesh revision source; refusing partial patch")
    rows = []
    if before:
        rows.append(run(["patch", "--batch", "--forward", "--fuzz=0", "-p1", "-i", str(MESH_PATCH)],
                        env, source, log, 30))
    require(all(sha(source / name) == hashes[1] for name, hashes in MESH_TARGETS.items()),
            "Patched mesh revision target SHA mismatch")
    return rows


def apply_retained_probe_patch(source, env, log):
    target = source / PROBE_TARGET
    actual = sha(target)
    require(actual in (PROBE_BEFORE_SHA, PROBE_AFTER_SHA), "Unexpected retained probe source bytes")
    rows = []
    if actual == PROBE_BEFORE_SHA:
        rows.append(run(["patch", "--batch", "--forward", "--fuzz=0", "-p1", "-i", str(PROBE_PATCH)],
                        env, source, log, 30))
    require(sha(target) == PROBE_AFTER_SHA, "Patched retained probe target SHA mismatch")
    return rows


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
        remaining = session_actors(process.pid)
    require(not remaining, f"Owned session actors remain: {remaining}")
    return {"command": command, "exit": code, "pid": process.pid,
            "start_ticks": start_tick, "seconds": round(time.monotonic() - started, 3)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--prepare", action="store_true")
    action.add_argument("--build", action="store_true")
    parser.add_argument("--target", choices=("editor", "template_release"), default="editor")
    parser.add_argument("--mesh-content-revision", action="store_true")
    parser.add_argument("--retained-probe-lifecycle", action="store_true")
    parser.add_argument("--jobs", type=int, choices=range(1, 5), default=2)
    parser.add_argument("--timeout", type=int, default=3600, help="Compile wall cap, at most 3600s")
    args = parser.parse_args()
    require(0 < args.timeout <= 3600, "Compile timeout must be 1..3600 seconds")
    source = CACHE / SOURCE_NAME
    suffix = MESH_SUFFIX if args.mesh_content_revision else SUFFIX
    build_name = MESH_BUILD_NAME if args.mesh_content_revision else BUILD_NAME
    if args.retained_probe_lifecycle:
        suffix += "_retained_probe_lifecycle"
        build_name += "_retained_probe_lifecycle"
    binary = source / (f"bin/godot.linuxbsd.{args.target}.x86_64." + suffix)
    options = ["target=" + args.target if option.startswith("target=") else option for option in OPTIONS]
    options = ["extra_suffix=" + suffix if option.startswith("extra_suffix=") else option for option in options]
    mode = "-mesh-content-revision" if args.mesh_content_revision else ""
    if args.retained_probe_lifecycle:
        mode += "-retained-probe-lifecycle"
    target_suffix = "" if args.target == "editor" else "-template_release"
    log = CACHE / f"build{mode}{target_suffix}.log"
    result = CACHE / f"build-result{mode}{target_suffix}.json"
    template_directory = "export_templates-mesh-content-revision" if args.mesh_content_revision else "export_templates"
    if args.retained_probe_lifecycle:
        template_directory += "-retained-probe-lifecycle"
    template = (CACHE / template_directory / "4.7.1.stable/linux_release.x86_64"
                if args.target == "template_release" else None)
    plan = {"source_commit": SOURCE_COMMIT, "source_url": SOURCE_URL, "source_sha256": SOURCE_SHA,
            "patch": str(PATCH), "patch_sha256": PATCH_SHA, "scons_version": "4.10.1",
            "scons_wheel_sha256": WHEEL_SHA, "cache": str(CACHE), "binary": str(binary),
            "custom_build_name": build_name, "options": options, "jobs": args.jobs,
            "target": args.target, "log": str(log), "result": str(result),
            "release_template": str(template) if template else None,
            "compile_timeout": args.timeout, "default_engine_templates_changed": False}
    if args.mesh_content_revision:
        plan.update(mesh_content_revision=True, mesh_patch=str(MESH_PATCH),
                    mesh_patch_sha256=MESH_PATCH_SHA)
    if args.retained_probe_lifecycle:
        plan.update(retained_probe_lifecycle=True, retained_probe_patch=str(PROBE_PATCH),
                    retained_probe_patch_sha256=PROBE_PATCH_SHA)
    print(json.dumps(plan, indent=2), flush=True)
    if not (args.prepare or args.build):
        return
    install_cancellation()
    require(sys.platform == "linux" and platform.machine() == "x86_64", "Linux x86_64 only")
    for tool in ("gcc", "g++", "ar", "pkg-config", "patch"):
        require(shutil.which(tool), "Missing build dependency: " + tool)
    require(sha(PATCH) == PATCH_SHA, "Reviewed patch bytes changed")
    if args.mesh_content_revision:
        require(sha(MESH_PATCH) == MESH_PATCH_SHA, "Reviewed mesh revision patch bytes changed")
    if args.retained_probe_lifecycle:
        require(sha(PROBE_PATCH) == PROBE_PATCH_SHA, "Reviewed retained probe patch bytes changed")
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
                   GIT_OPTIONAL_LOCKS="0", BUILD_NAME=build_name, SOURCE_DATE_EPOCH="0")
        archive = CACHE / (SOURCE_NAME + ".tar.xz")
        download(SOURCE_URL, archive, SOURCE_SHA)
        source_tree(archive, source, mesh_content_revision=args.mesh_content_revision,
                    retained_probe_lifecycle=args.retained_probe_lifecycle)
        wheel = CACHE / WHEEL_NAME
        download(WHEEL_URL, wheel, WHEEL_SHA)
        python = CACHE / "venv/bin/python"
        if not python.exists():
            venv.EnvBuilder(with_pip=True).create(CACHE / "venv")
        rows = [run([str(python), "-m", "pip", "install", "--no-index", "--no-deps",
                     "--disable-pip-version-check", str(wheel)], env, CACHE, log, 120)]
        if not args.build:
            print("PREPARED; patch unapplied unless already built; no compilation", flush=True)
            return
        if sha(source / TARGET) == BEFORE_SHA:
            rows.append(run(["patch", "--batch", "--forward", "--fuzz=0", "-p1", "-i", str(PATCH)],
                            env, source, log, 30))
        require(sha(source / TARGET) == AFTER_SHA, "Patched target SHA mismatch")
        if args.mesh_content_revision:
            rows.extend(apply_mesh_patch(source, env, log))
        if args.retained_probe_lifecycle:
            rows.extend(apply_retained_probe_patch(source, env, log))
        rows.append(run([str(python), "-m", "SCons", f"-j{args.jobs}", *options],
                        env, source, log, args.timeout))
        require(binary.is_file(), "Expected target binary missing")
        with binary.open("rb") as stream:
            require(stream.read(4) == b"\x7fELF", "Expected target ELF missing")
        rows.append(run([str(binary), "--headless", "--audio-driver", "Dummy", "--version"],
                        env, CACHE, log, 30))
        source_tree(archive, source, mesh_content_revision=args.mesh_content_revision,
                    retained_probe_lifecycle=args.retained_probe_lifecycle)
        if template:
            template.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            require(not template.is_symlink(), "Private release template must not be a symlink")
            if not template.exists():
                with binary.open("rb") as input_file, template.open("xb") as output_file:
                    shutil.copyfileobj(input_file, output_file)
                template.chmod(0o755)
            require(sha(template) == sha(binary), "Existing private release template differs from built target")
            plan["release_template_sha256"] = sha(template)
        plan.update(binary_sha256=sha(binary), binary_bytes=binary.stat().st_size, commands=rows,
                    purpose=("Private Linux --export-release template; runtime qualification NOT_RUN"
                             if template else "Explicit GODOT_BIN for station traversal/ReflectionProbe validation; not qualified"))
        result.write_text(json.dumps(plan, indent=2) + "\n")
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
