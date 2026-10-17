#!/usr/bin/env python3
"""Run one Linux suite with bounded ownership of even detached child processes."""
from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
from typing import Callable


def enable_subreaper() -> None:
    # Godot's OS.create_process() can start a new session. Killing only the
    # original process group misses those peers and their private X servers.
    # A dedicated supervisor adopts descendants when their parents exit.
    if sys.platform != "linux":
        raise RuntimeError("suite child supervision requires Linux")
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(36, 1, 0, 0, 0) != 0:  # PR_SET_CHILD_SUBREAPER
        raise OSError(ctypes.get_errno(), "cannot enable suite child subreaper")


def children() -> list[int]:
    pid = os.getpid()
    return [int(value) for value in Path(f"/proc/{pid}/task/{pid}/children").read_text().split()]


def reap(process: subprocess.Popen) -> list[int]:
    process.poll()  # Popen owns the root's exit status, including signal exits.
    for pid in children():
        if pid != process.pid:
            try:
                os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                pass
    return children()


def close_children(process: subprocess.Popen) -> bool:
    # Allow wrappers that already recorded success to finish their natural
    # Xvfb teardown. A leftover live peer is an error even if the suite passed.
    deadline = time.monotonic() + (0.25 if process.poll() is not None else 0.0)
    while reap(process):
        if time.monotonic() >= deadline:
            break
        time.sleep(0.01)
    else:
        return False

    for sig, grace in ((signal.SIGTERM, 1.0), (signal.SIGKILL, 3.0)):
        sent: set[int] = set()
        deadline = time.monotonic() + grace
        while remaining := reap(process):
            for pid in remaining:
                if pid not in sent:
                    # These are our unreaped children, so their PIDs cannot be
                    # recycled before this single-threaded owner signals them.
                    try:
                        os.kill(pid, sig)
                    except ProcessLookupError:
                        pass
                    sent.add(pid)
            if time.monotonic() >= deadline:
                break
            time.sleep(0.01)
        else:
            return True
    raise RuntimeError(f"suite children did not exit after SIGKILL: {children()}")


def run(command: list[str], timeout: float, *, _ready: Callable[[], None] | None = None) -> int:
    enable_subreaper()
    interrupted = 0

    def cancel(signum, _frame):
        nonlocal interrupted
        interrupted = interrupted or signum

    previous = {sig: signal.signal(sig, cancel) for sig in (signal.SIGINT, signal.SIGTERM)}
    process = None
    try:
        if _ready is not None:
            _ready()
        # Preserve the worker's inherited network/display flock descriptors,
        # as direct exec did: peers must retain the lane until teardown ends.
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, start_new_session=True,
                                   close_fds=False)
        deadline = time.monotonic() + timeout
        while process.poll() is None:
            if interrupted or time.monotonic() >= deadline:
                break
            time.sleep(0.02)
        timed_out = process.returncode is None and not interrupted
        code = 128 + interrupted if interrupted else 124 if timed_out else process.returncode
        leftover = close_children(process)
        if timed_out:
            print("ERROR: suite exceeded timeout; terminated and reaped owned processes", file=sys.stderr)
        elif interrupted:
            print("ERROR: suite interrupted; terminated and reaped owned processes", file=sys.stderr)
        elif leftover:
            print("ERROR: suite left owned child processes running; terminated and reaped", file=sys.stderr)
            if code == 0:
                code = 1
        if interrupted:
            return 128 + interrupted
        return 128 - code if code < 0 else code
    finally:
        if process is not None and (process.poll() is None or children()):
            close_children(process)
        for sig, handler in previous.items():
            signal.signal(sig, handler)


def write_status(path: Path, status: dict) -> None:
    """Publish one complete snapshot so readers never observe partial JSON."""
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", dir=path.parent,
                                         prefix=f".{path.name}.", delete=False) as output:
            temporary = Path(output.name)
            json.dump(status, output)
            output.write("\n")
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def detach(command: list[str], timeout: float, log_path: Path, status_path: Path) -> int:
    """Leave a session-independent owner; launcher success only means accepted."""
    if sys.platform != "linux":
        raise RuntimeError("detached suite supervision requires Linux")
    # Keep the final component lexical: resolving a dangling symlink would
    # bypass exclusive creation of an already existing artifact.
    log_path, status_path = log_path.absolute(), status_path.absolute()
    if log_path == status_path:
        raise RuntimeError("log and status paths must differ")
    # Reserve both paths before forking or starting work. Never silently reuse
    # old launch artifacts, which would make monitoring/cancellation ambiguous.
    log = log_path.open("x")
    try:
        with status_path.open("x"):
            pass
    except BaseException:
        log.close()
        log_path.unlink()
        raise
    try:
        launcher, owner = socket.socketpair()
        try:
            owner_pid = os.fork()
        except BaseException:
            launcher.close()
            owner.close()
            raise
    except BaseException:
        log.close()
        log_path.unlink()
        status_path.unlink()
        raise

    if owner_pid:
        log.close()
        owner.close()
        try:
            deadline = time.monotonic() + 10
            response = bytearray()
            while not response.endswith(b"\n"):
                launcher.settimeout(max(.001, deadline - time.monotonic()))
                chunk = launcher.recv(65536)
                if not chunk:
                    raise RuntimeError("detached owner exited before reporting readiness; inspect log")
                response.extend(chunk)
            result = json.loads(response)
            if "error" in result:
                raise RuntimeError(result["error"])
            # The command cannot start until its launcher acknowledges this
            # handoff. A failed/bounded handshake can therefore reap the owner
            # without orphaning an already running command.
            launcher.sendall(b"1")
        except BaseException:
            launcher.close()
            for sig in (None, signal.SIGTERM, signal.SIGKILL):
                if sig is not None:
                    try:
                        os.kill(owner_pid, sig)
                    except ProcessLookupError:
                        pass
                deadline = time.monotonic() + 1
                while time.monotonic() < deadline:
                    if os.waitpid(owner_pid, os.WNOHANG)[0]:
                        break
                    time.sleep(.01)
                else:
                    continue
                break
            raise
        finally:
            launcher.close()
        print(json.dumps(result), flush=True)
        return 0

    launcher.close()
    status = None
    code = 1
    completed = False
    try:
        os.setsid()
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        # run() installs cancellation handlers while it owns live children and
        # restores these afterward. Repeated cancellation must not interrupt
        # the final status publication after cleanup has already completed.
        for sig in (signal.SIGINT, signal.SIGTERM):
            signal.signal(sig, signal.SIG_IGN)
        with open(os.devnull) as input_file:
            os.dup2(input_file.fileno(), 0)
        os.dup2(log.fileno(), 1)
        os.dup2(log.fileno(), 2)
        log.close()
        # Keep all other inherited descriptors, especially worker flock lanes.
        # The owner must retain them until run() has reaped its descendants.
        start_ticks = int(Path(f"/proc/{os.getpid()}/stat").read_text().rsplit(")", 1)[1].split()[19])
        status = dict(state="RUNNING", owner_pid=os.getpid(), owner_start_ticks=start_ticks,
                      command=command, timeout=timeout, log_path=str(log_path),
                      status_path=str(status_path))

        def ready() -> None:
            write_status(status_path, status)
            owner.settimeout(10)
            owner.sendall((json.dumps(status) + "\n").encode())
            if owner.recv(1) != b"1":
                raise RuntimeError("launcher exited before acknowledging detached owner")
            owner.close()

        code = run(command, timeout, _ready=ready)
        completed = True
    except BaseException as error:
        message = f"detached suite supervisor: {error}"
        print(f"ERROR: {message}", file=sys.stderr, flush=True)
        try:
            owner.sendall((json.dumps(dict(error=message)) + "\n").encode())
        except OSError:
            pass
        if status is not None:
            status["error"] = message
    finally:
        owner.close()
        # Only normal run() return establishes that every owned process was
        # reaped. An exception may mean cleanup failed; expose ERROR instead.
        # Flush captured output before publishing either terminal snapshot.
        sys.stdout.flush()
        sys.stderr.flush()
        if status is not None:
            try:
                write_status(status_path, dict(status, state="FINISHED" if completed else "ERROR", exit_code=code))
            except OSError as error:
                print(f"ERROR: cannot write terminal suite status: {error}", file=sys.stderr, flush=True)
                code = 1
        os._exit(code)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("--detach", action="store_true",
                        help="return after a durable session-independent owner is ready")
    parser.add_argument("--log", type=Path, help="new output log path, required with --detach")
    parser.add_argument("--status", type=Path, help="new JSON status path, required with --detach")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or not 0 < args.timeout < float("inf"):
        parser.error("a command and positive finite timeout are required")
    if args.detach != (args.log is not None and args.status is not None) or (
            not args.detach and (args.log is not None or args.status is not None)):
        parser.error("--detach requires both --log and --status; paths require --detach")
    try:
        if args.detach:
            return detach(command, args.timeout, args.log, args.status)
        return run(command, args.timeout)
    except (OSError, RuntimeError) as error:
        print(f"ERROR: suite supervisor: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
