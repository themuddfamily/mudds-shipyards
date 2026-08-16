#!/usr/bin/env python3
"""Inspect an embedded Godot PCK and emit a deterministic JSON inventory."""

import argparse
import ctypes
import ctypes.util
import hashlib
import hmac
import json
import struct
import sys
from pathlib import Path, PurePosixPath


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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("executable", type=Path)
    parser.add_argument("-o", "--output", type=Path)
    args = parser.parse_args()
    try:
        data = args.executable.read_bytes()
        if data[:2] != b"MZ":
            raise ValueError("input is not a PE executable (missing MZ)")
        base, pack_end = find_pck(data)
        result = parse(data, base, pack_end)
        pe_offset = u32(data, 0x3C) if len(data) >= 64 else 0
        pe = {"offset": pe_offset}
        if pe_offset + 24 <= len(data) and data[pe_offset : pe_offset + 4] == b"PE\0\0":
            pe["machine"] = struct.unpack_from("<H", data, pe_offset + 4)[0]
            pe["sections"] = struct.unpack_from("<H", data, pe_offset + 6)[0]
        result["executable"] = {
            "path": str(args.executable),
            "sha256": hashlib.sha256(data).hexdigest(),
            "size": len(data),
            "pe": pe,
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
