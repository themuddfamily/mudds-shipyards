#!/usr/bin/env python3
"""Focused tests for package_inventory.py's bounded PCK/GDSC parser."""

import hashlib
import io
import json
import os
import stat
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_inventory as inventory  # noqa: E402
from test_release_candidate import fake_pe  # noqa: E402


ZSTD_16_ZERO_BYTES = bytes.fromhex("28b52ffd2010450000100000010032c002")


def _pad(value, alignment):
    return value + b"\0" * (-len(value) % alignment)


def build_exe(entries, *, pack_flags=inventory.PACK_REL_FILEBASE, elf=False):
    prefix = bytearray(128)
    prefix[:2] = b"MZ"
    struct.pack_into("<I", prefix, 0x3C, 64)
    prefix[64:68] = b"PE\0\0"
    if elf:
        prefix = bytearray(128)
        prefix[:7] = b"\x7fELF\x02\x01\x01"
        struct.pack_into("<HHI", prefix, 16, 2, 62, 1)
        struct.pack_into("<H", prefix, 52, 64)

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
    def run_cli(self, data):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "game"
            executable.write_bytes(data)
            return subprocess.run(
                [sys.executable, str(Path(inventory.__file__)), str(executable)],
                capture_output=True, text=True, check=False,
            )

    def test_cli_preserves_pe_json_contract(self):
        data = build_exe([("assets/data.bin", b"content")])
        completed = self.run_cli(data)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        result = json.loads(completed.stdout)
        self.assertEqual(result["executable"]["pe"], {
            "offset": 64, "machine": 0, "sections": 0,
        })
        self.assertEqual(set(result["executable"]), {"path", "sha256", "size", "pe"})
        self.assertEqual(result["executable"]["sha256"], hashlib.sha256(data).hexdigest())

    def test_cli_reads_elf64_embedded_pack_with_identical_payloads(self):
        entries = [("assets/data.bin", b"content")]
        pe_data = build_exe(entries)
        data = build_exe(entries, elf=True)
        completed = self.run_cli(data)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        result = json.loads(completed.stdout)
        base, end = inventory.find_pck(pe_data)
        pe_result = inventory.parse(pe_data, base, end)
        self.assertEqual(result["pck"], pe_result["pck"])
        self.assertEqual(result["entries"], pe_result["entries"])
        self.assertEqual(result["executable"]["elf"], {
            "class": 64, "byte_order": "little", "machine": 62,
        })
        self.assertEqual(set(result["executable"]), {"path", "sha256", "size", "elf"})
        self.assertEqual(result["executable"]["size"], len(data))
        self.assertEqual(result["executable"]["sha256"], hashlib.sha256(data).hexdigest())

    def test_cli_rejects_truncated_elf_header_or_pack(self):
        data = build_exe([("assets/data.bin", b"content")], elf=True)
        for truncated, message in ((data[:63], "truncated ELF64"),
                                   (data[:-1], "PCK trailer not found")):
            with self.subTest(message=message):
                completed = self.run_cli(truncated)
                self.assertEqual(completed.returncode, 2)
                self.assertIn(message, completed.stderr)
                self.assertEqual(completed.stdout, "")

    def test_cli_rejects_unsupported_elf_architecture_and_encoding(self):
        original = build_exe([("assets/data.bin", b"content")], elf=True)
        for offset, value, message in ((4, 1, "ELF64 little-endian"),
                                       (5, 2, "ELF64 little-endian"),
                                       (18, 183, "unsupported ELF machine"),
                                       (6, 2, "ELF header version"),
                                       (52, 63, "ELF64 header size")):
            with self.subTest(offset=offset):
                data = bytearray(original)
                data[offset] = value
                completed = self.run_cli(data)
                self.assertEqual(completed.returncode, 2)
                self.assertIn(message, completed.stderr)
                self.assertEqual(completed.stdout, "")

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


class PairedArtifactTests(unittest.TestCase):
    """Exercise the production CLI with independently constructed frozen packages."""

    EXPORTER = r'''#!/bin/bash
stem="${output_basename%.x86_64}"
package_dir_name="$stem"
desktop_basename="mudds-shipyards.desktop"
icon_basename="mudds-shipyards.png"
installer_basename="install-desktop-entry.sh"
managed_installer_basename="install_linux_desktop.py"
cat >"$package_root/$desktop_basename" <<DESKTOP
[Desktop Entry]
Exec=sh -c 'cd "\$(dirname "\$1")" && exec "./$output_basename"' mudds-shipyards %k
Icon=$icon_basename
X-MuddsShipyards-SourceCommit=$commit
DESKTOP
cat >"$package_root/$installer_basename" <<INSTALLER
#!/bin/sh
here=\$(cd "\$(dirname "\$0")" && pwd -P)
data_home=\${XDG_DATA_HOME:-\$HOME/.local/share}
sed -e "s|^Exec=.*|Exec=\\"\$here/$output_basename\\"|" \\
    "\$here/$desktop_basename"
INSTALLER
'''

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.repository = self.root / "source"
        self.repository.mkdir()
        for name, content in {
            "assets/keth-icon.png": b"frozen icon",
            "tools/release/install_linux_desktop.py": b"#!/usr/bin/python3\n# frozen manager\n",
            "tools/release/export_linux_candidate.sh": self.EXPORTER.encode(),
        }.items():
            path = self.repository / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        self.git("init", "-q")
        self.git("config", "user.name", "Fixture")
        self.git("config", "user.email", "fixture@example.invalid")
        self.git("add", ".")
        self.git("commit", "-q", "-m", "compiled source")
        self.commit = self.git("rev-parse", "HEAD").strip()
        self.epoch = int(self.git("show", "-s", "--format=%ct", self.commit))
        # A newer checkout must never replace the compiled source's Git objects.
        (self.repository / "assets/keth-icon.png").write_bytes(b"newer icon")
        (self.repository / "tools/release/export_linux_candidate.sh").write_text("exit 99\n")
        self.git("add", ".")
        self.git("commit", "-q", "-m", "newer source")

        self.binary_name = "MuddsShipyards-fixture.x86_64"
        self.package_root = "MuddsShipyards-fixture"
        self.entries = [("assets/data.bin", b"content"), ("assets/other.bin", b"other")]
        # Reuse the independent resource-bearing PE fixture, adding a real .text.
        prefix = bytearray(fake_pe()[:0x400])
        struct.pack_into("<H", prefix, 0x86, 2)
        section = 0x98 + 240 + 40
        prefix[section:section + 8] = b".text\0\0\0"
        self.code = b"complete stock engine code" + bytes(range(32))
        struct.pack_into("<IIII", prefix, section + 8, len(self.code), 0x2000,
                         len(self.code), len(prefix))
        self.template_data = bytes(prefix) + self.code
        self.windows_data = self.template_data + build_exe(self.entries)[128:]
        self.linux_data = build_exe(self.entries, elf=True)
        self.files = {
            "executable": self.root / "game.exe",
            "compare_linux": self.root / self.binary_name,
            "linux_archive": self.root / "candidate-linux-x86_64.tar.gz",
            "linux_export_result": self.root / "export-result.json",
            "windows_template": self.root / "stock.exe",
            "expected_inventory": self.root / "approved-inventory.json",
            "windows_zip": self.root / "checkpoint.zip",
            "windows_notes": self.root / "notes.txt",
        }
        self.files["executable"].write_bytes(self.windows_data)
        self.files["compare_linux"].write_bytes(self.linux_data)
        self.files["windows_template"].write_bytes(self.template_data)
        self.files["windows_notes"].write_bytes(b"Player-visible checkpoint notes\n")
        base, end = inventory.find_pck(self.windows_data)
        self.files["expected_inventory"].write_text(json.dumps(inventory.parse(self.windows_data, base, end)))
        # These expected generated bytes are literal fixtures, not tool output.
        desktop = (
            '[Desktop Entry]\n'
            f'Exec=sh -c \'cd "$(dirname "$1")" && exec "./{self.binary_name}"\' mudds-shipyards %k\n'
            'Icon=mudds-shipyards.png\n'
            f'X-MuddsShipyards-SourceCommit={self.commit}\n'
        ).encode()
        installer = (
            '#!/bin/sh\n'
            'here=$(cd "$(dirname "$0")" && pwd -P)\n'
            'data_home=${XDG_DATA_HOME:-$HOME/.local/share}\n'
            f'sed -e "s|^Exec=.*|Exec=\\"$here/{self.binary_name}\\"|" \\\n'
            '    "$here/mudds-shipyards.desktop"\n'
        ).encode()
        self.payloads = {
            self.binary_name: (self.linux_data, 0o755),
            "mudds-shipyards.png": (b"frozen icon", 0o644),
            "install_linux_desktop.py": (b"#!/usr/bin/python3\n# frozen manager\n", 0o755),
            "mudds-shipyards.desktop": (desktop, 0o755),
            "install-desktop-entry.sh": (installer, 0o755),
        }
        self.tar_changes = {}
        self.write_tar()
        self.write_zip()
        self.output = self.root / "audit.json"

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repository), *args], text=True)

    def write_tar(self, *, extra=None, omit=None, duplicate=None, root_mode=0o755):
        with tarfile.open(self.files["linux_archive"], "w:gz") as archive:
            root = tarfile.TarInfo(self.package_root)
            root.type = tarfile.DIRTYPE
            root.mode, root.mtime = root_mode, self.epoch
            archive.addfile(root)
            for name, (content, mode) in self.payloads.items():
                if name == omit:
                    continue
                member = tarfile.TarInfo(f"{self.package_root}/{name}")
                member.mode, member.mtime, member.size = mode, self.epoch, len(content)
                for field, value in self.tar_changes.get(name, {}).items():
                    if field == "content":
                        content = value
                        member.size = len(content)
                    else:
                        setattr(member, field, value)
                archive.addfile(member, io.BytesIO(content))
                if name == duplicate:
                    archive.addfile(member, io.BytesIO(content))
            if extra:
                archive.addfile(tarfile.TarInfo(extra), io.BytesIO())
        self.refresh_export()

    def refresh_export(self):
        def describe(path):
            return {"path": "/removed/export/worktree/" + path.name,
                    "bytes": path.stat().st_size,
                    "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        self.export = {
            "schema_version": 1, "platform": "linux", "architecture": "x86_64",
            "source_commit": self.commit, "tarball_root": self.package_root,
            "binary": describe(self.files["compare_linux"]),
            "tarball": describe(self.files["linux_archive"]),
        }
        self.files["linux_export_result"].write_text(json.dumps(self.export))

    def write_zip(self, *, exe=None, notes=None, extra=None, omit=None):
        with zipfile.ZipFile(self.files["windows_zip"], "w") as archive:
            if omit != "exe":
                archive.writestr(self.files["executable"].name, self.windows_data if exe is None else exe)
            if omit != "notes":
                archive.writestr(self.files["windows_notes"].name,
                                 self.files["windows_notes"].read_bytes() if notes is None else notes)
            if extra:
                archive.writestr(extra, b"extra")

    def command(self):
        command = [sys.executable, inventory.__file__, str(self.files["executable"])]
        for name, path in self.files.items():
            if name != "executable":
                command.extend(["--" + name.replace("_", "-"), str(path)])
        command.extend([
            "--windows-template-sha256", hashlib.sha256(self.template_data).hexdigest(),
            "--source-repository", str(self.repository), "--source-commit", self.commit,
            "-o", str(self.output),
        ])
        return command

    def run_pair(self, *, failure=None, command=None):
        # Every successful and failing audit must leave all supplied inputs alone.
        before = {name: (hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_mode)
                  for name, path in self.files.items()}
        completed = subprocess.run(command or self.command(), capture_output=True, text=True)
        after = {name: (hashlib.sha256(path.read_bytes()).hexdigest(), path.stat().st_mode)
                 for name, path in self.files.items()}
        self.assertEqual(before, after)
        if failure is None:
            self.assertEqual(completed.returncode, 0, completed.stderr)
        else:
            self.assertEqual(completed.returncode, 2, completed.stderr)
        result = json.loads(self.output.read_text())
        self.assertEqual(result["status"], "PASS" if failure is None else "FAIL")
        self.assertTrue(result["inputs_unchanged"])
        if failure:
            self.assertEqual(result["first_failed_predicate"], failure)
            self.assertNotIn('"PASS"', self.output.read_text())
        return result

    def test_valid_pair_reads_older_git_source_and_complete_maps(self):
        result = self.run_pair()
        self.assertEqual(result["source_commit"], self.commit)
        self.assertNotEqual(self.git("rev-parse", "HEAD").strip(), self.commit)
        self.assertEqual(result["entry_count"], 2)
        self.assertEqual(result["declared_windows_template_sha256"],
                         result["observed_windows_template_sha256"])

    def test_root_directory_mode_is_not_an_invented_contract(self):
        self.write_tar(root_mode=0o700)
        self.run_pair()

    def test_template_pin_precedes_code_comparison(self):
        self.files["windows_template"].write_bytes(self.template_data + b"changed")
        self.run_pair(failure="windows_template_pin")

    def test_wrong_machine_and_complete_text_change_fail(self):
        for offset in (0x84, 0x400 + len(self.code) - 1):
            with self.subTest(offset=offset):
                changed = bytearray(self.windows_data)
                changed[offset] ^= 1
                self.files["executable"].write_bytes(changed)
                self.run_pair(failure="executable_headers_and_code")

    def test_wrong_elf_header_fails(self):
        changed = bytearray(self.linux_data)
        changed[18] = 183
        self.files["compare_linux"].write_bytes(changed)
        self.run_pair(failure="executable_headers_and_code")

    def test_expected_manifest_missing_extra_changed_and_malformed_fail(self):
        original = json.loads(self.files["expected_inventory"].read_text())
        cases = [None, {"schema_version": 1, "entries": []}]
        for mutation in ("missing", "extra", "changed", "duplicate"):
            document = json.loads(json.dumps(original))
            if mutation == "missing":
                document["entries"].pop()
            elif mutation == "extra":
                document["entries"].append({"path": "assets/extra.bin", "size": 1, "sha256": "0" * 64})
            elif mutation == "changed":
                document["entries"][-1]["sha256"] = "0" * 64
            else:
                document["entries"].append(document["entries"][0])
            cases.append(document)
        for index, document in enumerate(cases):
            with self.subTest(case=index):
                self.files["expected_inventory"].write_text(json.dumps(document))
                self.run_pair(failure="approved_complete_inventories")

    def test_either_platform_changed_pack_and_invalid_digest_fail(self):
        altered_entries = [("assets/data.bin", b"changed"), self.entries[1]]
        for platform in ("executable", "compare_linux"):
            with self.subTest(platform=platform):
                data = (self.template_data + build_exe(altered_entries)[128:]
                        if platform == "executable" else build_exe(altered_entries, elf=True))
                self.files[platform].write_bytes(data)
                self.run_pair(failure="approved_complete_inventories")
                self.files[platform].write_bytes(self.windows_data if platform == "executable" else self.linux_data)
        damaged = bytearray(self.linux_data)
        damaged[128 + 112] ^= 1
        self.files["compare_linux"].write_bytes(damaged)
        self.run_pair(failure="approved_complete_inventories")

    def test_linux_export_source_platform_and_artifact_identities_fail(self):
        for field in ("source_commit", "platform", "architecture", "tarball_root", "binary", "tarball"):
            with self.subTest(field=field):
                document = json.loads(json.dumps(self.export))
                if field in ("binary", "tarball"):
                    document[field]["sha256"] = "0" * 64
                else:
                    document[field] = "wrong"
                self.files["linux_export_result"].write_text(json.dumps(document))
                self.run_pair(failure="linux_export_result")

    def test_tar_payload_bytes_modes_owners_and_epoch_fail(self):
        for name in self.payloads:
            with self.subTest(payload=name):
                content = self.payloads[name][0]
                self.tar_changes = {name: {"content": bytes([content[0] ^ 1]) + content[1:]}}
                self.write_tar()
                self.run_pair(failure="linux_archive")
        for field, value in (("mode", 0o777), ("uid", 1), ("gid", 1), ("mtime", self.epoch + 1)):
            with self.subTest(field=field):
                self.tar_changes = {self.binary_name: {field: value}}
                self.write_tar()
                self.run_pair(failure="linux_archive")

    def test_tar_duplicate_extra_missing_unsafe_and_link_fail(self):
        cases = ({"duplicate": self.binary_name, "omit": "mudds-shipyards.png"},
                 {"extra": "unexpected", "omit": self.binary_name},
                 {"omit": self.binary_name},
                 {"extra": f"{self.package_root}/../escape", "omit": self.binary_name})
        for changes in cases:
            with self.subTest(changes=changes):
                self.write_tar(**changes)
                self.run_pair(failure="linux_archive")
        for kind in (tarfile.SYMTYPE, tarfile.LNKTYPE):
            with self.subTest(kind=kind):
                self.tar_changes = {self.binary_name: {"type": kind, "linkname": "elsewhere", "size": 0}}
                self.write_tar()
                self.run_pair(failure="linux_archive")

    def test_zip_wrong_bytes_extra_missing_duplicate_and_crc_fail(self):
        for changes in ({"exe": b"X" + self.windows_data[1:]},
                        {"notes": self.files["windows_notes"].read_bytes().upper()},
                        {"extra": "extra"}, {"omit": "notes"}):
            with self.subTest(changes=changes):
                self.write_zip(**changes)
                self.run_pair(failure="windows_zip")
        with zipfile.ZipFile(self.files["windows_zip"], "w") as archive:
            archive.writestr(self.files["executable"].name, self.windows_data)
            with self.assertWarns(UserWarning):
                archive.writestr(self.files["executable"].name, b"duplicate")
        self.run_pair(failure="windows_zip")
        self.write_zip()
        data = bytearray(self.files["windows_zip"].read_bytes())
        # Alter the stored first payload, leaving both ZIP CRCs unchanged.
        first_payload = 30 + len(self.files["executable"].name.encode())
        data[first_payload + len(self.windows_data) - 1] ^= 1
        self.files["windows_zip"].write_bytes(data)
        self.run_pair(failure="windows_zip")

    def test_nonexistent_source_and_unsupported_exporter_expression_fail(self):
        command = self.command()
        command[command.index("--source-commit") + 1] = "0" * 40
        self.run_pair(failure="compiled_source", command=command)
        path = self.repository / "tools/release/export_linux_candidate.sh"
        path.write_text(self.EXPORTER.replace("Icon=$icon_basename", "Icon=$(touch SHOULD_NOT_EXIST)"))
        self.git("add", ".")
        self.git("commit", "-q", "-m", "unsupported exporter template")
        self.commit = self.git("rev-parse", "HEAD").strip()
        self.run_pair(failure="compiled_source")
        self.assertFalse((self.root / "SHOULD_NOT_EXIST").exists())
        self.assertFalse((self.repository / "SHOULD_NOT_EXIST").exists())

    def test_zip_rejects_explicit_special_files_and_accepts_regular_metadata(self):
        cases = (
            (stat.S_IFLNK, 0, "windows_zip"),
            (stat.S_IFCHR, 0, "windows_zip"),
            (stat.S_IFDIR, 0, "windows_zip"),
            (0, 0x10, "windows_zip"),
            (stat.S_IFREG, 0, None),
            (0, 0, None),
        )
        for file_type, dos_attributes, failure in cases:
            with self.subTest(file_type=file_type, dos_attributes=dos_attributes):
                with zipfile.ZipFile(self.files["windows_zip"], "w") as archive:
                    member = zipfile.ZipInfo(self.files["executable"].name)
                    member.create_system = 3 if file_type else 0
                    member.external_attr = ((file_type | 0o644) << 16) | dos_attributes
                    archive.writestr(member, self.windows_data)
                    archive.writestr(self.files["windows_notes"].name,
                                     self.files["windows_notes"].read_bytes())
                self.run_pair(failure=failure)

    def test_template_expansion_rejects_unknown_shell_expressions(self):
        for expression in ("$unknown", "${commit:0:7}", "$(false)", "`false`"):
            with self.subTest(expression=expression):
                with self.assertRaisesRegex(ValueError, "unsupported template expression"):
                    inventory._expand_heredoc(expression, {"commit": self.commit})
        self.assertEqual(inventory._expand_heredoc(r'\$HOME ${commit} \\ "literal"', {"commit": "abc"}),
                         b'$HOME abc \\ "literal"')

    def test_partial_pair_options_fail_and_output_cannot_alias_any_input(self):
        completed = subprocess.run([sys.executable, inventory.__file__, str(self.files["executable"]),
                                    "--compare-linux", str(self.files["compare_linux"])],
                                   capture_output=True, text=True)
        self.assertEqual(completed.returncode, 2)
        self.assertIn("requires all pair options", completed.stderr)
        for path in self.files.values():
            for link_type in ("direct", "symlink", "hardlink"):
                with self.subTest(input=path.name, alias=link_type):
                    alias = self.root / "alias"
                    if alias.exists() or alias.is_symlink():
                        alias.unlink()
                    if link_type == "symlink":
                        alias.symlink_to(path)
                    elif link_type == "hardlink":
                        os.link(path, alias)
                    output = path if link_type == "direct" else alias
                    command = self.command()
                    command[-1] = str(output)
                    before = hashlib.sha256(path.read_bytes()).hexdigest()
                    completed = subprocess.run(command, capture_output=True, text=True)
                    self.assertEqual(completed.returncode, 2)
                    self.assertIn("output aliases input", completed.stderr)
                    self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)


if __name__ == "__main__":
    unittest.main()
