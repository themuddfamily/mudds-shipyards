#!/usr/bin/env python3
"""Focused tests for package_inventory.py's bounded PCK/GDSC parser."""

import hashlib
import struct
import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_inventory as inventory  # noqa: E402


ZSTD_16_ZERO_BYTES = bytes.fromhex("28b52ffd2010450000100000010032c002")


def _pad(value, alignment):
    return value + b"\0" * (-len(value) % alignment)


def build_exe(entries, *, pack_flags=inventory.PACK_REL_FILEBASE):
    prefix = bytearray(128)
    prefix[:2] = b"MZ"
    struct.pack_into("<I", prefix, 0x3C, 64)
    prefix[64:68] = b"PE\0\0"

    header = bytearray(104)
    struct.pack_into("<4s5I", header, 0, b"GDPC", 4, 4, 7, 1, pack_flags)
    file_base = 112
    struct.pack_into("<Q", header, 24, file_base)
    pack = header + bytearray(file_base - len(header))

    records = []
    for path, payload in entries:
        pack.extend(b"\0" * (-len(pack) % 16))
        offset = len(pack) - file_base
        pack.extend(payload)
        records.append((path, offset, payload))

    pack.extend(b"\0" * (-len(pack) % 16))
    directory_offset = len(pack)
    struct.pack_into("<Q", pack, 32, directory_offset)
    pack.extend(struct.pack("<I", len(records)))
    for path, offset, payload in records:
        encoded_path = _pad(path.encode("utf-8"), 4)
        pack.extend(struct.pack("<I", len(encoded_path)))
        pack.extend(encoded_path)
        pack.extend(struct.pack("<QQ", offset, len(payload)))
        pack.extend(hashlib.md5(payload).digest())
        pack.extend(struct.pack("<I", 0))
    pack.extend(b"\0" * (-(len(pack) + 12) % 8))
    return bytes(prefix + pack + struct.pack("<Q4s", len(pack), b"GDPC"))


class PackageInventoryTests(unittest.TestCase):
    def parse_exe(self, entries, **kwargs):
        data = build_exe(entries, **kwargs)
        base, pack_end = inventory.find_pck(data)
        return data, inventory.parse(data, base, pack_end)

    def test_format4_directory_and_gdsc_are_validated_and_sorted(self):
        gdsc = b"GDSC" + struct.pack("<II", 101, 16) + ZSTD_16_ZERO_BYTES
        data, result = self.parse_exe(
            [("scripts/zeta.gdc", gdsc), ("assets/alpha.bin", b"alpha")]
        )
        self.assertEqual([entry["path"] for entry in result["entries"]], [
            "assets/alpha.bin",
            "scripts/zeta.gdc",
        ])
        self.assertEqual(result["pck"]["format"], 4)
        self.assertEqual(result["pck"]["entry_count"], 2)
        self.assertEqual(inventory.find_pck(data)[1], len(data) - 12)

    def test_rejects_wrong_pck_md5(self):
        data = bytearray(build_exe([("assets/data.bin", b"content")]))
        base, pack_end = inventory.find_pck(data)
        directory = base + inventory.u64(data, base + 32)
        path_length = inventory.u32(data, directory + 4)
        digest = directory + 8 + path_length + 16
        data[digest] ^= 1
        with self.assertRaisesRegex(ValueError, "MD5 mismatch"):
            inventory.parse(data, base, pack_end)

    def test_rejects_entry_outside_data_region(self):
        data = bytearray(build_exe([("assets/data.bin", b"content")]))
        base, pack_end = inventory.find_pck(data)
        directory = base + inventory.u64(data, base + 32)
        path_length = inventory.u32(data, directory + 4)
        offset_field = directory + 8 + path_length
        struct.pack_into("<Q", data, offset_field, 1 << 63)
        with self.assertRaisesRegex(ValueError, "outside PCK bounds"):
            inventory.parse(data, base, pack_end)

    def test_rejects_path_traversal(self):
        with self.assertRaisesRegex(ValueError, "path traversal"):
            self.parse_exe([("assets/../tests/escape.gdc", b"bad")])

    def test_rejects_forbidden_release_path(self):
        with self.assertRaisesRegex(ValueError, "forbidden release paths"):
            self.parse_exe([("tools/release-helper.bin", b"bad")])

    def test_rejects_duplicate_casefolded_paths(self):
        with self.assertRaisesRegex(ValueError, "duplicate PCK path"):
            self.parse_exe([
                ("assets/Data.bin", b"one"),
                ("assets/data.bin", b"two"),
            ])

    def test_rejects_wrong_gdsc_decompression_size(self):
        gdsc = b"GDSC" + struct.pack("<II", 101, 17) + ZSTD_16_ZERO_BYTES
        with self.assertRaisesRegex(ValueError, "decompression size disagrees"):
            self.parse_exe([("scripts/bad.gdc", gdsc)])

    def test_rejects_concatenated_gdsc_zstd_frames(self):
        gdsc = (
            b"GDSC"
            + struct.pack("<II", 101, 16)
            + ZSTD_16_ZERO_BYTES
            + ZSTD_16_ZERO_BYTES
        )
        with self.assertRaisesRegex(ValueError, "trailing or concatenated"):
            self.parse_exe([("scripts/bad.gdc", gdsc)])

    def test_rejects_encrypted_directory_flag(self):
        with self.assertRaisesRegex(ValueError, "encrypted directory"):
            self.parse_exe(
                [("assets/data.bin", b"content")],
                pack_flags=inventory.PACK_DIR_ENCRYPTED | inventory.PACK_REL_FILEBASE,
            )


if __name__ == "__main__":
    unittest.main()
