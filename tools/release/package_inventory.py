#!/usr/bin/env python3
"""Inspect an embedded Godot PCK and emit a deterministic JSON inventory."""

import argparse
import ctypes
import ctypes.util
import hashlib
import hmac
import json
import re
import stat
import struct
import subprocess
import sys
import tarfile
import zipfile
from pathlib import Path, PurePosixPath

try:
    from . import release_candidate
except ImportError:
    import release_candidate


PACK_MAGIC = b"GDPC"
PACK_DIR_ENCRYPTED = 1 << 0
PACK_REL_FILEBASE = 1 << 1
PACK_SPARSE_BUNDLE = 1 << 2
PACK_FILE_ENCRYPTED = 1 << 0
PACK_FILE_REMOVAL = 1 << 1
PACK_FILE_DELTA = 1 << 2

FORBIDDEN = ("tests/", "artifacts/", "tools/")
RAW = (".gd", ".tscn", ".tres")
MAX_ENTRY_COUNT = 1_000_000
MAX_PATH_BYTES = 1 << 20
MAX_GDSC_SIZE = 256 << 20
GDSCRIPT_TOKENIZER_VERSION = 101  # Godot 4.7.1 (a13da4feb).
ZSTD_MAGIC = b"\x28\xb5\x2f\xfd"


def u32(data, offset):
    return struct.unpack_from("<I", data, offset)[0]


def u64(data, offset):
    return struct.unpack_from("<Q", data, offset)[0]


def _checked_end(start, size, limit, description):
    if start < 0 or size < 0 or start > limit or size > limit - start:
        raise ValueError(f"{description} outside PCK bounds")
    return start + size


def find_pck(data):
    """Return the start and exclusive data end of an EOF-embedded PCK.

    Godot writes ``uint64 pck_size`` and a second ``GDPC`` after the pack. Using
    that trailer avoids mistaking engine code or payload bytes for a PCK header.
    """
    if len(data) < 12 or data[-4:] != PACK_MAGIC:
        raise ValueError("embedded PCK trailer not found at end of executable")
    pack_size = u64(data, len(data) - 12)
    if pack_size < 104 or pack_size > len(data) - 12:
        raise ValueError("invalid embedded PCK size in trailer")
    base = len(data) - 12 - pack_size
    if data[base : base + 4] != PACK_MAGIC:
        raise ValueError("embedded PCK trailer does not point to a GDPC header")
    return base, len(data) - 12


def _decode_path(raw, index):
    if not raw or len(raw) % 4:
        raise ValueError(f"entry {index} has an invalid padded path length")
    nul = raw.find(b"\0")
    if nul >= 0:
        if any(raw[nul:]) or len(raw) - nul > 3:
            raise ValueError(f"entry {index} has invalid path padding")
        raw = raw[:nul]
    if not raw:
        raise ValueError(f"entry {index} has an empty path")
    path = raw.decode("utf-8")
    if (
        path.startswith("/")
        or path.endswith("/")
        or "\\" in path
        or "//" in path
        or ":" in path
    ):
        raise ValueError(f"unsafe PCK path: {path!r}")
    parts = PurePosixPath(path).parts
    if not parts or any(part in ("", ".", "..") for part in parts):
        raise ValueError(f"unsafe PCK path traversal: {path!r}")
    if "/".join(parts) != path:
        raise ValueError(f"non-canonical PCK path: {path!r}")
    return path


class _Zstd:
    """Small, dependency-free binding for validating Godot's one-frame GDSC."""

    CONTENTSIZE_UNKNOWN = (1 << 64) - 1
    CONTENTSIZE_ERROR = (1 << 64) - 2

    def __init__(self):
        name = ctypes.util.find_library("zstd")
        if not name:
            raise ValueError("cannot validate compressed GDSC: libzstd not found")
        self.lib = ctypes.CDLL(name)
        self.lib.ZSTD_isError.argtypes = [ctypes.c_size_t]
        self.lib.ZSTD_isError.restype = ctypes.c_uint
        self.lib.ZSTD_getErrorName.argtypes = [ctypes.c_size_t]
        self.lib.ZSTD_getErrorName.restype = ctypes.c_char_p
        self.lib.ZSTD_getFrameContentSize.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
        self.lib.ZSTD_getFrameContentSize.restype = ctypes.c_ulonglong
        self.lib.ZSTD_findFrameCompressedSize.argtypes = [ctypes.c_void_p, ctypes.c_size_t]
        self.lib.ZSTD_findFrameCompressedSize.restype = ctypes.c_size_t
        self.lib.ZSTD_decompress.argtypes = [
            ctypes.c_void_p,
            ctypes.c_size_t,
            ctypes.c_void_p,
            ctypes.c_size_t,
        ]
        self.lib.ZSTD_decompress.restype = ctypes.c_size_t

    def _error(self, result):
        if self.lib.ZSTD_isError(result):
            detail = self.lib.ZSTD_getErrorName(result).decode("ascii", "replace")
            raise ValueError(f"invalid GDSC zstd frame: {detail}")
        return result

    def decompress_one_frame(self, compressed, expected_size):
        if not compressed.startswith(ZSTD_MAGIC):
            raise ValueError("compressed GDSC does not start with a zstd frame")
        source = ctypes.create_string_buffer(compressed)
        frame_size = self._error(
            self.lib.ZSTD_findFrameCompressedSize(source, len(compressed))
        )
        if frame_size != len(compressed):
            raise ValueError("compressed GDSC has trailing or concatenated zstd data")
        declared_size = self.lib.ZSTD_getFrameContentSize(source, len(compressed))
        if declared_size in (self.CONTENTSIZE_UNKNOWN, self.CONTENTSIZE_ERROR):
            raise ValueError("compressed GDSC has no bounded zstd content size")
        if declared_size != expected_size:
            raise ValueError(
                "GDSC decompression size disagrees with the zstd frame "
                f"({expected_size} != {declared_size})"
            )
        destination = ctypes.create_string_buffer(expected_size)
        actual_size = self._error(
            self.lib.ZSTD_decompress(
                destination, expected_size, source, len(compressed)
            )
        )
        if actual_size != expected_size:
            raise ValueError(
                f"GDSC decompressed to {actual_size} bytes, expected {expected_size}"
            )
        return destination.raw[:actual_size]


_zstd = None


def _validate_gdsc(payload, path):
    if len(payload) < 12 or payload[:4] != b"GDSC":
        raise ValueError(f"compiled GDScript entry lacks a GDSC header: {path}")
    version, decompressed_size = struct.unpack_from("<II", payload, 4)
    if version != GDSCRIPT_TOKENIZER_VERSION:
        raise ValueError(f"unsupported GDSC tokenizer version {version}: {path}")
    if decompressed_size > MAX_GDSC_SIZE:
        raise ValueError(f"unreasonable GDSC decompression size: {path}")
    if decompressed_size == 0:
        contents = payload[12:]
    else:
        if decompressed_size < 16:
            raise ValueError(f"invalid GDSC decompression size: {path}")
        global _zstd
        if _zstd is None:
            _zstd = _Zstd()
        contents = _zstd.decompress_one_frame(payload[12:], decompressed_size)
    if len(contents) < 16:
        raise ValueError(f"truncated GDSC tokenizer buffer: {path}")


def _directory_location(data, base, pack_end, format_version):
    if format_version in (3, 4):
        if base + 104 > pack_end:
            raise ValueError("truncated PCK v3/v4 header")
        directory_offset = u64(data, base + 32)
        if any(data[base + 40 : base + 104]):
            raise ValueError("unsupported non-zero PCK header extension")
        directory = _checked_end(base, directory_offset, pack_end, "PCK directory")
    else:
        raise ValueError(
            f"unsupported PCK format {format_version}; only v3/v4 offset directories are supported"
        )
    if directory + 4 > pack_end:
        raise ValueError("PCK directory offset is outside the pack")
    return directory_offset, directory


def parse(data, base, pack_end=None):
    if pack_end is None:
        pack_end = len(data)
    if base < 0 or pack_end > len(data) or base + 32 > pack_end:
        raise ValueError("truncated PCK header")
    if data[base : base + 4] != PACK_MAGIC:
        raise ValueError("invalid PCK magic")

    format_version, major, minor, patch, pack_flags = struct.unpack_from(
        "<5I", data, base + 4
    )
    unsupported_pack_flags = pack_flags & ~PACK_REL_FILEBASE
    if unsupported_pack_flags:
        names = []
        if unsupported_pack_flags & PACK_DIR_ENCRYPTED:
            names.append("encrypted directory")
        if unsupported_pack_flags & PACK_SPARSE_BUNDLE:
            names.append("sparse bundle")
        raise ValueError(
            "unsupported PCK flags: "
            + ", ".join(names or [hex(unsupported_pack_flags)])
        )
    if format_version in (3, 4) and not (pack_flags & PACK_REL_FILEBASE):
        raise ValueError("PCK v3/v4 without relative file-base offsets is unsupported")

    raw_file_base = u64(data, base + 24)
    file_base = (
        base + raw_file_base
        if pack_flags & PACK_REL_FILEBASE
        else raw_file_base
    )
    directory_offset, directory = _directory_location(
        data, base, pack_end, format_version
    )
    if file_base < base + 104 or file_base > directory:
        raise ValueError("PCK file base is outside the data region")

    count = u32(data, directory)
    if count == 0:
        raise ValueError("PCK directory has no entries")
    if count > MAX_ENTRY_COUNT:
        raise ValueError("unreasonable PCK entry count")

    pos = directory + 4
    entries = []
    paths = set()
    folded_paths = set()
    regions = []
    for index in range(count):
        if pos + 4 > pack_end:
            raise ValueError("truncated PCK entry table")
        path_length = u32(data, pos)
        pos += 4
        if path_length == 0 or path_length > MAX_PATH_BYTES:
            raise ValueError(f"entry {index} has an unreasonable path length")
        path_end = _checked_end(pos, path_length, pack_end, "PCK path")
        path = _decode_path(data[pos:path_end], index)
        pos = path_end
        if pos + 36 > pack_end:
            raise ValueError("truncated PCK entry table")
        offset = u64(data, pos)
        size = u64(data, pos + 8)
        digest = data[pos + 16 : pos + 32]
        entry_flags = u32(data, pos + 32)
        pos += 36

        unsupported_entry_flags = entry_flags & (
            PACK_FILE_ENCRYPTED | PACK_FILE_REMOVAL | PACK_FILE_DELTA
        )
        if unsupported_entry_flags or entry_flags:
            raise ValueError(f"unsupported PCK entry flags {entry_flags:#x}: {path}")
        if path in paths or path.casefold() in folded_paths:
            raise ValueError(f"duplicate PCK path: {path}")
        paths.add(path)
        folded_paths.add(path.casefold())

        absolute = file_base + offset
        payload_end = _checked_end(absolute, size, directory, f"entry {path!r}")
        payload = data[absolute:payload_end]
        actual_digest = hashlib.md5(payload).digest()
        if not hmac.compare_digest(digest, actual_digest):
            raise ValueError(f"PCK MD5 mismatch: {path}")
        if path.lower().endswith(".gdc") or payload.startswith(b"GDSC"):
            _validate_gdsc(payload, path)
        if size:
            regions.append((absolute, payload_end, path))
        entries.append(
            {
                "path": path,
                "offset": absolute,
                "size": size,
                "flags": entry_flags,
                "sha256": hashlib.sha256(payload).hexdigest(),
                "pck_md5": digest.hex(),
            }
        )

    # Exported entries are independent files. Overlap indicates a corrupt or
    # malicious directory offset even when both slices happen to hash correctly.
    regions.sort()
    for previous, current in zip(regions, regions[1:]):
        if current[0] < previous[1]:
            raise ValueError(
                f"overlapping PCK entries: {previous[2]} and {current[2]}"
            )

    # The writer pads the embedded directory to an 8-byte boundary. Refuse any
    # other trailing data before the size/magic trailer.
    if pack_end - pos > 7 or any(data[pos:pack_end]):
        raise ValueError("unexpected data after PCK directory")

    entries.sort(key=lambda entry: entry["path"])
    forbidden = [
        entry["path"]
        for entry in entries
        if entry["path"].lower().startswith(FORBIDDEN)
        or entry["path"].lower().endswith(RAW)
    ]
    if forbidden:
        raise ValueError("forbidden release paths: " + ", ".join(forbidden[:8]))

    manifest = "\n".join(entry["path"] for entry in entries).encode("utf-8")
    return {
        "schema_version": 1,
        "pck": {
            "offset": base,
            "size": pack_end - base,
            "format": format_version,
            "godot_version": [major, minor, patch],
            "flags": pack_flags,
            "file_base": raw_file_base,
            "directory_offset": directory_offset,
            "entry_count": len(entries),
            "sorted_path_manifest_sha256": hashlib.sha256(manifest).hexdigest(),
        },
        "entries": entries,
    }


def executable_metadata(data):
    """Identify supported export executables without changing the PE contract."""
    if data[:2] == b"MZ":
        pe_offset = u32(data, 0x3C) if len(data) >= 64 else 0
        pe = {"offset": pe_offset}
        if pe_offset + 24 <= len(data) and data[pe_offset : pe_offset + 4] == b"PE\0\0":
            pe["machine"] = struct.unpack_from("<H", data, pe_offset + 4)[0]
            pe["sections"] = struct.unpack_from("<H", data, pe_offset + 6)[0]
        return {"pe": pe}
    if data[:4] == b"\x7fELF":
        if len(data) < 64:
            raise ValueError("truncated ELF64 executable header")
        if data[4] != 2 or data[5] != 1:
            raise ValueError("only ELF64 little-endian executables are supported")
        machine = struct.unpack_from("<H", data, 18)[0]
        if machine != 62:
            raise ValueError(f"unsupported ELF machine {machine}; expected x86_64 (62)")
        if data[6] != 1 or u32(data, 20) != 1:
            raise ValueError("unsupported ELF header version")
        if struct.unpack_from("<H", data, 52)[0] != 64:
            raise ValueError("invalid ELF64 header size")
        return {"elf": {"class": 64, "byte_order": "little", "machine": machine}}
    raise ValueError("input is not a PE or ELF executable (missing MZ or ELF)")


PAIR_OPTIONS = (
    "compare_linux", "linux_archive", "linux_export_result", "windows_template",
    "windows_template_sha256", "source_repository", "source_commit",
    "expected_inventory", "windows_zip", "windows_notes",
)
PAIR_FILES = (
    "executable", "compare_linux", "linux_archive", "linux_export_result",
    "windows_template", "expected_inventory", "windows_zip", "windows_notes",
)
SHA256 = re.compile(r"[0-9a-f]{64}\Z")


def _require(condition, message):
    if not condition:
        raise ValueError(message)


def _describe(path):
    metadata = path.stat()
    _require(stat.S_ISREG(metadata.st_mode), f"input is not a regular file: {path}")
    with path.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    return {
        "path": str(path), "size": metadata.st_size,
        "sha256": digest, "mode": stat.S_IMODE(metadata.st_mode),
    }


def _refuse_output_alias(output, inputs):
    if output is None:
        return
    for path in inputs:
        _require(output.resolve() != path.resolve(), f"output aliases input: {path}")
        if output.exists() and path.exists():
            _require(not output.samefile(path), f"output aliases input: {path}")


def _git(repository, *arguments):
    completed = subprocess.run(
        ["git", "-C", str(repository), *arguments], capture_output=True, check=False,
        timeout=15,
    )
    _require(completed.returncode == 0, "cannot read declared source Git object: "
             + completed.stderr.decode("utf-8", "replace").strip())
    return completed.stdout


def _source_inputs(repository, commit):
    _require(re.fullmatch(r"[0-9a-f]{40,64}", commit) is not None,
             "source commit must be an exact full Git commit ID")
    resolved = _git(repository, "rev-parse", "--verify", "--end-of-options",
                    commit + "^{commit}").decode("ascii").strip()
    _require(resolved == commit, "source commit is not the declared exact commit")
    epoch = int(_git(repository, "show", "-s", "--format=%ct", commit).strip())
    _require(epoch >= 0, "invalid source commit epoch")
    files = {
        name: _git(repository, "show", f"{commit}:{name}")
        for name in (
            "assets/keth-icon.png", "tools/release/install_linux_desktop.py",
            "tools/release/export_linux_candidate.sh",
        )
    }
    return epoch, files


def _expand_heredoc(template, values):
    """Expand only literal unquoted Bash heredoc syntax, without executing it.

    Backslash quotes $, backtick, backslash and newline in this context. Quotes
    themselves are literal. Substituted values are never rescanned as shell code.
    """
    output = []
    position = 0
    while position < len(template):
        char = template[position]
        if char == "\\" and position + 1 < len(template):
            following = template[position + 1]
            if following in "$`\\\n":
                if following != "\n":
                    output.append(following)
                position += 2
                continue
        if char == "`":
            raise ValueError("unsupported template expression: command substitution")
        if char == "$":
            match = re.match(r"\$(?:\{([A-Za-z_][A-Za-z_0-9]*)\}|([A-Za-z_][A-Za-z_0-9]*))",
                             template[position:])
            _require(match is not None, "unsupported template expression after $")
            name = match.group(1) or match.group(2)
            _require(name in values, f"unsupported template expression: {name}")
            output.append(values[name])
            position += len(match.group(0))
            continue
        output.append(char)
        position += 1
    return "".join(output).encode("utf-8")


def _source_helpers(exporter, binary_name, commit):
    text = exporter.decode("utf-8")
    _require(re.fullmatch(r"[A-Za-z0-9._-]+\.x86_64", binary_name) is not None
             and binary_name != ".x86_64", "unsupported Linux binary basename")
    # These are the supported release-value declarations, not a shell evaluator.
    for declaration in ('stem="${output_basename%.x86_64}"', 'package_dir_name="$stem"'):
        variable = declaration.split("=", 1)[0]
        _require(text.splitlines().count(declaration) == 1
                 and len(re.findall(rf"^{variable}=", text, re.MULTILINE)) == 1,
                 f"unsupported exporter declaration: {declaration}")
    values = {"output_basename": binary_name, "commit": commit}
    for variable in ("desktop_basename", "icon_basename", "installer_basename",
                     "managed_installer_basename"):
        matches = re.findall(rf'^{variable}="([A-Za-z0-9._-]+)"$', text, re.MULTILINE)
        _require(len(matches) == 1
                 and len(re.findall(rf"^{variable}=", text, re.MULTILINE)) == 1,
                 f"unsupported exporter declaration: {variable}")
        _require(matches[0] not in (".", ".."), "unsafe helper basename")
        values[variable] = matches[0]
    _require(len(set(values[name] for name in values if name.endswith("basename"))) == 5,
             "duplicate exporter payload basename")
    helpers = {}
    for variable, delimiter in (("desktop_basename", "DESKTOP"),
                                ("installer_basename", "INSTALLER")):
        marker = f'cat >"$package_root/${variable}" <<{delimiter}\n'
        _require(text.count(marker) == 1, f"unsupported exporter {delimiter} template")
        remainder = text.split(marker, 1)[1]
        end = remainder.find(f"\n{delimiter}\n")
        _require(end >= 0, f"unterminated exporter {delimiter} template")
        helpers[values[variable]] = _expand_heredoc(remainder[:end + 1], values)
    root = binary_name[:-len(".x86_64")]
    _require(root not in (".", ".."), "unsafe Linux package root")
    return root, values, helpers


def _entry_map(document):
    _require(isinstance(document, dict) and document.get("schema_version") == 1,
             "expected inventory must use the existing schema_version 1 format")
    entries = document.get("entries")
    _require(isinstance(entries, list) and 0 < len(entries) <= MAX_ENTRY_COUNT,
             "inventory must contain a nonempty entries list")
    result = {}
    folded = set()
    for entry in entries:
        _require(isinstance(entry, dict), "malformed inventory entry")
        path, size, digest = entry.get("path"), entry.get("size"), entry.get("sha256")
        _require(isinstance(path, str), "inventory entry path must be a string")
        raw = path.encode("utf-8")
        _decode_path(raw + b"\0" * (-len(raw) % 4), "expected")
        _require(path not in result and path.casefold() not in folded,
                 f"duplicate inventory path: {path}")
        _require(type(size) is int and size >= 0 and isinstance(digest, str)
                 and SHA256.fullmatch(digest) is not None,
                 f"invalid inventory size/SHA256: {path}")
        result[path] = (size, digest)
        folded.add(path.casefold())
    return result


def _compare_map(actual, expected, platform):
    missing, extra = sorted(expected.keys() - actual.keys()), sorted(actual.keys() - expected.keys())
    _require(not missing, f"{platform} inventory missing entry: {missing[:1]}")
    _require(not extra, f"{platform} inventory extra entry: {extra[:1]}")
    changed = [path for path in sorted(expected) if actual[path] != expected[path]]
    _require(not changed, f"{platform} inventory changed entry: {changed[:1]}")


def _pe_text(data):
    metadata = release_candidate.inspect_pe(data)
    _require(metadata["pe"]["machine"] == 0x8664, "PE machine must be x86_64 (0x8664)")
    header = u32(data, 0x3C)
    count = struct.unpack_from("<H", data, header + 6)[0]
    table = header + 24 + struct.unpack_from("<H", data, header + 20)[0]
    for index in range(count):
        section = table + 40 * index
        if data[section:section + 8].split(b"\0", 1)[0] == b".text":
            size, offset = struct.unpack_from("<II", data, section + 16)
            _require(size > 0, "PE .text section is empty")
            return metadata, data[offset:offset + size]
    raise ValueError("PE lacks a .text section")


def _equal_stream(stream, expected, label):
    position = 0
    while True:
        chunk = stream.read(1 << 20)
        if not chunk:
            break
        _require(chunk == expected[position:position + len(chunk)], f"changed payload: {label}")
        position += len(chunk)
    _require(position == len(expected), f"changed payload size: {label}")


def _audit_tar(path, root, payloads, epoch):
    with tarfile.open(path, "r:*") as archive:
        members = archive.getmembers()
        _require(len(members) == 6, "Linux tar must have exactly six members")
        seen = set()
        for member in members:
            name = member.name
            _require(name not in seen, f"duplicate Linux tar member: {name}")
            seen.add(name)
            _require(name == root or name in payloads, f"unsafe or unexpected Linux tar member: {name}")
            _require(not member.pax_headers, f"unsupported Linux tar extended metadata: {name}")
            _require(member.uid == 0 and member.gid == 0 and member.mtime == epoch,
                     f"wrong Linux tar owner/epoch: {name}")
            if name == root:
                _require(member.isdir(), "Linux tar root must be a directory")
            else:
                expected, mode = payloads[name]
                _require(member.isfile(), f"Linux tar payload must be regular: {name}")
                _require(member.mode == mode, f"wrong Linux tar payload mode: {name}")
                _require(member.size == len(expected), f"wrong Linux tar payload size: {name}")
                with archive.extractfile(member) as stream:
                    _equal_stream(stream, expected, name)
        _require(seen == {root, *payloads}, "missing Linux tar member")


def _audit_zip(path, payloads):
    with zipfile.ZipFile(path) as archive:
        members = archive.infolist()
        _require(len(members) == 2 and len({item.filename for item in members}) == 2,
                 "Windows ZIP must have exactly two unique members")
        _require({item.filename for item in members} == set(payloads),
                 "Windows ZIP must contain exactly the named EXE and notes")
        for member in members:
            _require(not member.is_dir(), "Windows ZIP payload must be a file")
            file_type = stat.S_IFMT(member.external_attr >> 16)
            _require(file_type in (0, stat.S_IFREG) and not member.external_attr & 0x10,
                     f"Windows ZIP payload must be regular: {member.filename}")
            _require(member.file_size == len(payloads[member.filename]),
                     f"wrong Windows ZIP payload size: {member.filename}")
            # ZipExtFile checks the CRC when the complete member is read.
            with archive.open(member) as stream:
                _equal_stream(stream, payloads[member.filename], member.filename)


def audit_pair(args):
    """Read a frozen artifact pair; stop at the first failed production predicate."""
    result = {
        "status": "FAIL", "source_commit": args.source_commit,
        "source_repository": str(args.source_repository),
        "declared_windows_template_sha256": args.windows_template_sha256,
        "completed_predicates": [], "inputs": {},
    }
    predicate = "input_identity"
    paths = {name: getattr(args, name) for name in PAIR_FILES}
    try:
        result["inputs"] = {name: _describe(path) for name, path in paths.items()}
        result["audit_driver_commit"] = _git(
            Path(__file__).resolve().parent, "rev-parse", "HEAD"
        ).decode("ascii").strip()
        result["completed_predicates"].append(predicate)

        predicate = "compiled_source"
        epoch, source_files = _source_inputs(args.source_repository, args.source_commit)
        result["source_epoch"] = epoch
        result["source_files"] = {
            name: {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
            for name, data in source_files.items()
        }
        root, names, helpers = _source_helpers(
            source_files["tools/release/export_linux_candidate.sh"],
            args.compare_linux.name, args.source_commit,
        )
        result["completed_predicates"].append(predicate)

        predicate = "windows_template_pin"
        observed = result["inputs"]["windows_template"]["sha256"]
        result["observed_windows_template_sha256"] = observed
        _require(SHA256.fullmatch(args.windows_template_sha256) is not None,
                 "declared Windows template hash must be a lowercase SHA256")
        _require(observed == args.windows_template_sha256, "Windows template SHA256 pin mismatch")
        result["completed_predicates"].append(predicate)

        predicate = "executable_headers_and_code"
        windows, linux = args.executable.read_bytes(), args.compare_linux.read_bytes()
        metadata, text = _pe_text(windows)
        _, template_text = _pe_text(args.windows_template.read_bytes())
        _require(text == template_text, "complete PE .text differs from pinned Windows template")
        linux_metadata = executable_metadata(linux)
        _require("elf" in linux_metadata, "Linux executable must be ELF64 little-endian x86_64")
        result["windows_pe"] = metadata["pe"]
        result["linux_elf"] = linux_metadata["elf"]
        result["windows_text_sha256"] = hashlib.sha256(text).hexdigest()
        result["completed_predicates"].append(predicate)

        predicate = "approved_complete_inventories"
        expected = _entry_map(json.loads(args.expected_inventory.read_text(encoding="utf-8")))
        for platform, data in (("Windows", windows), ("Linux", linux)):
            base, end = find_pck(data)
            actual = _entry_map(parse(data, base, end))
            _compare_map(actual, expected, platform)
        result["entry_count"] = len(expected)
        result["completed_predicates"].append(predicate)

        predicate = "linux_export_result"
        export = json.loads(args.linux_export_result.read_text(encoding="utf-8"))
        _require(isinstance(export, dict), "Linux export result must be an object")
        _require(export.get("platform") == "linux" and export.get("architecture") == "x86_64",
                 "wrong Linux export platform/architecture")
        _require(export.get("source_commit") == args.source_commit, "wrong Linux export source")
        _require(export.get("tarball_root") == root, "wrong Linux export tarball root")
        for field, name in (("binary", "compare_linux"), ("tarball", "linux_archive")):
            record, observed = export.get(field), result["inputs"][name]
            _require(isinstance(record, dict), f"missing Linux export {field} identity")
            _require(isinstance(record.get("path"), str)
                     and PurePosixPath(record["path"]).name == paths[name].name,
                     f"wrong Linux export {field} basename")
            _require(type(record.get("bytes")) is int and record["bytes"] == observed["size"]
                     and record.get("sha256") == observed["sha256"],
                     f"wrong Linux export {field} size/SHA256")
        result["completed_predicates"].append(predicate)

        predicate = "linux_archive"
        payloads = {
            f"{root}/{args.compare_linux.name}": (linux, 0o755),
            f"{root}/{names['icon_basename']}": (source_files["assets/keth-icon.png"], 0o644),
            f"{root}/{names['managed_installer_basename']}":
                (source_files["tools/release/install_linux_desktop.py"], 0o755),
            **{f"{root}/{name}": (data, 0o755) for name, data in helpers.items()},
        }
        _audit_tar(args.linux_archive, root, payloads, epoch)
        result["completed_predicates"].append(predicate)

        predicate = "windows_zip"
        _audit_zip(args.windows_zip, {
            args.executable.name: windows, args.windows_notes.name: args.windows_notes.read_bytes(),
        })
        result["completed_predicates"].append(predicate)
    except (OSError, ValueError, struct.error, UnicodeError, tarfile.TarError,
            zipfile.BadZipFile, RuntimeError, subprocess.SubprocessError,
            release_candidate.EvidenceError) as error:
        result["first_failed_predicate"] = predicate
        result["error"] = str(error)

    # Verify even on predicate failure. Preserve the first failure if one exists.
    try:
        after = {name: _describe(path) for name, path in paths.items()}
        result["inputs_unchanged"] = after == result["inputs"]
        _require(result["inputs_unchanged"], "input bytes or modes changed during audit")
        if "first_failed_predicate" not in result:
            result["completed_predicates"].append("inputs_unchanged")
            result["status"] = "PASS"
    except (OSError, ValueError) as error:
        result["inputs_unchanged"] = False
        if "first_failed_predicate" not in result:
            result["first_failed_predicate"] = "inputs_unchanged"
            result["error"] = str(error)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    for name in PAIR_OPTIONS:
        parser.add_argument("--" + name.replace("_", "-"),
                            type=str if name in ("source_commit", "windows_template_sha256") else Path)
    args = parser.parse_args()
    pair_mode = any(getattr(args, name) is not None for name in PAIR_OPTIONS)
    if pair_mode and (not all(getattr(args, name) is not None for name in PAIR_OPTIONS)
                      or args.output is None):
        parser.error("paired audit requires all pair options and -o/--output")
    try:
        _refuse_output_alias(args.output, [getattr(args, name) for name in
                                          (PAIR_FILES if pair_mode else ("executable",))])
        if pair_mode:
            result = audit_pair(args)
            args.output.write_text(json.dumps(result, sort_keys=True, indent=2) + "\n", encoding="utf-8")
            if result["status"] != "PASS":
                print(f"package-inventory: ERROR: {result['first_failed_predicate']}: {result['error']}",
                      file=sys.stderr)
                return 2
            return 0
        data = args.executable.read_bytes()
        metadata = executable_metadata(data)
        base, pack_end = find_pck(data)
        result = parse(data, base, pack_end)
        result["executable"] = {
            "path": str(args.executable),
            "sha256": hashlib.sha256(data).hexdigest(),
            "size": len(data),
            **metadata,
        }
        output = json.dumps(result, sort_keys=True, indent=2) + "\n"
        if args.output:
            args.output.write_text(output, encoding="utf-8")
        else:
            sys.stdout.write(output)
    except (OSError, ValueError, struct.error, UnicodeError) as error:
        print(f"package-inventory: ERROR: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
