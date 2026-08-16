#!/usr/bin/env python3
"""Focused fake-fixture tests for the release-candidate evidence gate."""

import hashlib
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))
import release_candidate as candidate  # noqa: E402


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fake_pe():
    data = bytearray(0x400)
    data[:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", data, 0x84, 0x8664, 1, 123456, 0, 0, 240, 0x22E)
    optional = 0x98
    struct.pack_into("<H", data, optional, 0x20B)
    struct.pack_into("<Q", data, optional + 24, 0x140000000)
    struct.pack_into("<I", data, optional + 60, 0x200)
    struct.pack_into("<I", data, optional + 64, 0x12345678)
    struct.pack_into("<H", data, optional + 68, 2)
    struct.pack_into("<I", data, optional + 108, 16)
    struct.pack_into("<II", data, optional + 112 + 16, 0x1000, 180)
    section = optional + 240
    data[section : section + 8] = b".rsrc\0\0\0"
    struct.pack_into("<IIII", data, section + 8, 0x200, 0x1000, 0x200, 0x200)

    resource = 0x200
    struct.pack_into("<HH", data, resource + 12, 0, 1)
    struct.pack_into("<II", data, resource + 16, 16, 0x80000018)
    struct.pack_into("<HH", data, resource + 24 + 12, 0, 1)
    struct.pack_into("<II", data, resource + 24 + 16, 1, 0x80000030)
    struct.pack_into("<HH", data, resource + 48 + 12, 0, 1)
    struct.pack_into("<II", data, resource + 48 + 16, 0x409, 72)

    key = "VS_VERSION_INFO\0".encode("utf-16le")
    fixed = struct.pack(
        "<13I",
        0xFEEF04BD,
        0x00010000,
        0x00010002,
        0x00030004,
        0x00050006,
        0x00070008,
        0x3F,
        0,
        0x40004,
        1,
        0,
        0,
        0,
    )
    version = bytearray(struct.pack("<HHH", 92, 52, 0) + key)
    version.extend(b"\0" * (-len(version) % 4))
    version.extend(fixed)
    struct.pack_into("<IIII", data, resource + 72, 0x1058, len(version), 1200, 0)
    data[resource + 88 : resource + 88 + len(version)] = version

    pack = b"GDPC" + b"\0" * 100
    return bytes(data) + pack + struct.pack("<Q4s", len(pack), b"GDPC")


class ReleaseCandidateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.repository = self.root / "source"
        self.repository.mkdir()
        (self.repository / "project.godot").write_text("[application]\n", encoding="utf-8")
        subprocess.run(["git", "init", "-q"], cwd=self.repository, check=True)
        subprocess.run(["git", "config", "user.name", "Fixture"], cwd=self.repository, check=True)
        subprocess.run(["git", "config", "user.email", "fixture@example.invalid"], cwd=self.repository, check=True)
        subprocess.run(["git", "add", "project.godot"], cwd=self.repository, check=True)
        commit_env = {
            **os.environ,
            "GIT_AUTHOR_DATE": "2026-08-16T00:00:00Z",
            "GIT_COMMITTER_DATE": "2026-08-16T00:00:00Z",
        }
        subprocess.run(
            ["git", "commit", "-q", "-m", "fixture source"],
            cwd=self.repository,
            env=commit_env,
            check=True,
        )
        self.revision = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=self.repository, text=True
        ).strip()
        self.short_revision = self.revision[:7]

        self.evidence = self.root / "evidence"
        self.evidence.mkdir()
        self.godot = self.evidence / "godot"
        self.godot.write_text(
            "#!/bin/sh\nprintf '%s\\n' '4.7.1.stable.official.fixture'\n",
            encoding="utf-8",
        )
        self.godot.chmod(0o755)
        self.artifact = self.evidence / f"MuddsShipyards-{self.short_revision}.exe"
        artifact_data = fake_pe()
        self.artifact.write_bytes(artifact_data)

        source_raw, source_count = candidate.source_scope_manifest(
            self.repository, ["project.godot"]
        )
        source_before = self.evidence / "source-manifest-before.csv"
        source_after = self.evidence / "source-manifest-after.csv"
        source_before.write_bytes(source_raw)
        source_after.write_bytes(source_raw)
        source_sha = sha256(source_raw)
        canonical = self.evidence / "results-canonical.tsv"
        canonical_raw = (
            "test_path\tstatus\texit_code\tsentinel\tsentinel_count\tpass_assertions\t"
            "diagnostic_count\tfailure_flags\n"
            "tests/fake_test.gd\tPASS\t0\tFAKE_OK\t1\t3\t0\t\n"
        ).encode()
        canonical.write_bytes(canonical_raw)
        self.matrix_manifest = self.evidence / "matrix-manifest.txt"
        self.matrix_manifest.write_text(
            "\n".join(
                [
                    "run_id=fake-matrix",
                    "run_started_utc=2026-08-16T00:00:00Z",
                    "run_completed_utc=2026-08-16T00:01:00Z",
                    f"godot_binary={self.godot}",
                    "overall_status=PASS",
                    "total_suites=1",
                    f"source_manifest_before_sha={source_sha}",
                    f"source_manifest_after_sha={source_sha}",
                    "source_manifest_match=true",
                    f"source_manifest_before_count={source_count}",
                    f"source_manifest_after_count={source_count}",
                    f"source_manifest_before={source_before}",
                    f"source_manifest_after={source_after}",
                    "scope_specs=all",
                    "manifest_scope=project.godot",
                    "total_pass_assertions=3",
                    "failed_suite_count=0",
                    f"results_canonical_tsv={canonical}",
                    f"results_canonical_sha={sha256(canonical_raw)}",
                ]
            )
            + "\n",
            encoding="utf-8",
        )

        probe_log = self.evidence / "probe.log"
        probe_log.write_text("FAKE_PROBE_OK\n", encoding="utf-8")
        probe_results = self.evidence / "probe-results.tsv"
        probe_results.write_text(
            "test_path\tstatus\texit_code\tsentinel\tsentinel_count\tpass_assertions\t"
            "diagnostic_count\tduration_ms\tlog_path\tlog_sha256\treasons\n"
            f"tests/fake_probe.gd\tPASS\t0\tFAKE_PROBE_OK\t1\t2\t0\t1\t{probe_log}\t"
            f"{candidate._sha256_file(probe_log)}\t\n",
            encoding="utf-8",
        )
        self.probe_manifest = self.evidence / "probe-manifest.txt"
        self.probe_manifest.write_text(
            "\n".join(
                [
                    "run_id=fake-probes",
                    "run_started_utc=2026-08-16T00:02:00Z",
                    "run_completed_utc=2026-08-16T00:03:00Z",
                    f"package_path={self.artifact}",
                    f"godot_binary={self.godot}",
                    "overall_status=PASS",
                    "total_probes=1",
                    f"results_tsv={probe_results}",
                ]
            )
            + "\n",
            encoding="utf-8",
        )

        pck_size = struct.unpack_from("<Q", artifact_data, len(artifact_data) - 12)[0]
        pck_offset = len(artifact_data) - 12 - pck_size
        payload = artifact_data[pck_offset : pck_offset + 4]
        path = "assets/fake.bin"
        inventory = {
            "schema_version": 1,
            "executable": {
                "path": str(self.artifact),
                "size": len(artifact_data),
                "sha256": sha256(artifact_data),
            },
            "pck": {
                "offset": pck_offset,
                "size": pck_size,
                "format": 4,
                "godot_version": [4, 7, 1],
                "entry_count": 1,
                "sorted_path_manifest_sha256": sha256(path.encode()),
            },
            "entries": [
                {
                    "path": path,
                    "offset": pck_offset,
                    "size": len(payload),
                    "flags": 0,
                    "sha256": sha256(payload),
                    "pck_md5": hashlib.md5(payload, usedforsecurity=False).hexdigest(),
                }
            ],
        }
        self.inventory = self.evidence / "inventory.json"
        self.inventory.write_text(
            json.dumps(inventory, sort_keys=True, indent=2) + "\n", encoding="utf-8"
        )

    def tearDown(self):
        self.temporary.cleanup()

    def build(self):
        return candidate.build_candidate(
            self.repository,
            self.artifact,
            self.matrix_manifest,
            self.probe_manifest,
            self.inventory,
            self.godot,
        )

    def test_writes_deterministic_schema_valid_record_and_sums(self):
        record = self.build()
        repeated = self.build()
        self.assertEqual(
            json.dumps(record, sort_keys=True, indent=2),
            json.dumps(repeated, sort_keys=True, indent=2),
        )
        candidate.validate_record_schema(record)
        record_path, sums_path = candidate.write_candidate(
            record, self.artifact, self.artifact.parent
        )
        self.assertEqual(record["status"], "PASS")
        self.assertFalse(record["source"]["dirty"])
        self.assertEqual(record["artifact"]["signing"]["status"], "unsigned")
        self.assertEqual(record["artifact"]["pe"]["file_version"], [1, 2, 3, 4])
        sums = sums_path.read_text(encoding="ascii").splitlines()
        self.assertEqual(sums, sorted(sums, key=lambda line: line.split("  ", 1)[1]))
        self.assertIn(candidate._sha256_file(record_path), sums[1])

    def test_rejects_dirty_source(self):
        (self.repository / "untracked.txt").write_text("dirty", encoding="utf-8")
        with self.assertRaisesRegex(candidate.EvidenceError, "worktree is dirty"):
            self.build()

    def test_rejects_artifact_short_sha_mismatch(self):
        renamed = self.artifact.with_name("MuddsShipyards-deadbee.exe")
        self.artifact.rename(renamed)
        self.artifact = renamed
        with self.assertRaisesRegex(candidate.EvidenceError, "does not match source"):
            self.build()

    def test_rejects_failed_matrix(self):
        text = self.matrix_manifest.read_text(encoding="utf-8")
        self.matrix_manifest.write_text(
            text.replace("overall_status=PASS", "overall_status=FAIL"),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(candidate.EvidenceError, "did not PASS"):
            self.build()

    def test_rejects_missing_probe_log(self):
        (self.evidence / "probe.log").unlink()
        with self.assertRaisesRegex(candidate.EvidenceError, "missing package-probe log"):
            self.build()

    def test_rejects_incorrect_inventory_path_manifest(self):
        inventory = json.loads(self.inventory.read_text(encoding="utf-8"))
        inventory["pck"]["sorted_path_manifest_sha256"] = "0" * 64
        self.inventory.write_text(json.dumps(inventory), encoding="utf-8")
        with self.assertRaisesRegex(candidate.EvidenceError, "path-manifest"):
            self.build()


if __name__ == "__main__":
    unittest.main()
