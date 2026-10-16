#!/usr/bin/env python3
"""Run one Linux suite with bounded ownership of even detached child processes."""
from __future__ import annotations

import argparse
import ctypes
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


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


def run(command: list[str], timeout: float) -> int:
    enable_subreaper()
    interrupted = 0

    def cancel(signum, _frame):
        nonlocal interrupted
        interrupted = interrupted or signum

    previous = {sig: signal.signal(sig, cancel) for sig in (signal.SIGINT, signal.SIGTERM)}
    process = None
    try:
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--timeout", type=float, required=True)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ["--"] else args.command
    if not command or not 0 < args.timeout < float("inf"):
        parser.error("a command and positive finite timeout are required")
    try:
        return run(command, args.timeout)
    except (OSError, RuntimeError) as error:
        print(f"ERROR: suite supervisor: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
