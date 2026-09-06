#!/usr/bin/env python3
"""Shared recursive suite discovery and source-declared completion contracts.

This is runner support, not proof of a suite's correctness: exit status and engine
diagnostics remain independent gates. Rendering readback is conservatively run
with a display, even when a particular suite makes its capture optional.
"""
from __future__ import annotations
import argparse
import re
from pathlib import Path

RENDER_MARKERS = ("RenderingServer.frame_post_draw", ".get_texture().get_image()", "get_viewport().get_texture()")
PRINT_LITERAL = re.compile(r'''\bprint\(\s*["']([^"'\n]+)["']''')
TOKEN = re.compile(r"^([A-Z][A-Z0-9_]*(?:_OK|_PASS))(?=[:\s]|$)")


def suites(root: Path):
    return sorted(p for p in (root / "tests").rglob("*_test.gd") if not p.is_symlink())


def mode(path: Path) -> str:
    source = path.read_text(encoding="utf-8")
    return "graphical" if any(marker in source for marker in RENDER_MARKERS) else "headless"


def completion_patterns(path: Path):
    """Only accept completion forms actually printed by this suite's source.

    Older suites use a filename sentinel, newer ones use OK/PASS descriptions or
    assertion summaries. A normal PASS: assertion is never a completion marker.
    """
    source = path.read_text(encoding="utf-8")
    patterns = {}
    # Preserve the established dynamically generated filename-token convention.
    for suffix in ("OK", "PASS"):
        token = path.stem.upper() + "_" + suffix
        patterns[token] = re.compile(r"^\s*" + token + r"(?=\s|:|$).*$")
    # Normalize the established print("prefix", _assertions, " suffix") form.
    source = re.sub(r'(print\(\s*["\'][^"\'\n]*)["\']\s*,\s*_(?:assertions|checks)\s*,\s*["\']', r'\1%d', source)
    for literal in PRINT_LITERAL.findall(source):
        token = TOKEN.match(literal)
        if token:
            name = token[1]
            patterns[name] = re.compile(r"^\s*" + name + r"(?=\s|:|$).*$")
            continue
        # A free-form assertion description must never become a completion
        # contract (e.g. print("PASS %s" % description)). Summary contracts have
        # authored static text and, when formatted, only numeric counts.
        if "%s" in literal or literal.strip(" :") in ("OK", "PASS"):
            continue
        is_summary = (
            re.match(r"^(OK[: ]|PASS )", literal)
            or (literal.startswith("PASS:") and "%d assertions" in literal)
            or re.search(r"tests? passed(?::|$)", literal)
            or literal.endswith(" TEST PASS")
            or ("assertions" in literal and "%d" in literal and "fail" not in literal.lower())
            or re.search(r"%d checks, (?:%d|0) failures", literal)
        )
        if not is_summary:
            continue
        # Summary formats contain counts; require zero explicitly reported failures.
        literal = literal.replace("%d failures", "0 failures")
        pieces = re.split(r"(%[ds])", literal)
        expression = "".join(r"[0-9]+" if p == "%d" else r".+" if p == "%s" else re.escape(p) for p in pieces)
        name = literal.split("%", 1)[0].rstrip(" (:,")
        patterns[name] = re.compile(r"^\s*" + expression + r"\s*$")
    return patterns


def assess(path: Path, log: Path):
    patterns = completion_patterns(path)
    lines = [line.rstrip("\r") for line in log.read_text(encoding="utf-8", errors="replace").splitlines() if line.strip()]
    matches = [(i, name) for i, line in enumerate(lines) for name, pattern in patterns.items() if pattern.fullmatch(line)]
    # Several source declarations can describe the same token; count log lines once.
    unique = dict(matches)
    found = next(iter(unique.values()), "<none>")
    terminal = unique.get(len(lines) - 1, "<none>")
    assertions = sum(line.startswith("PASS:") and i not in unique for i, line in enumerate(lines))
    if not assertions and unique:
        summary = lines[next(iter(unique))]
        count = re.search(r"\b([0-9]+) (?:assertions|checks)\b", summary)
        if count:
            assertions = int(count[1])
    return found, len(unique), terminal, assertions


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--mode", choices=("all", "headless", "graphical"), default="all")
    parser.add_argument("--assess", nargs=2, metavar=("SCRIPT", "LOG"))
    args = parser.parse_args()
    if args.assess:
        print("\t".join(map(str, assess(*map(Path, args.assess)))))
    else:
        for path in suites(args.root):
            kind = mode(path)
            if args.mode in ("all", kind):
                print(f"{path.relative_to(args.root).as_posix()}\t{kind}")


if __name__ == "__main__":
    main()
