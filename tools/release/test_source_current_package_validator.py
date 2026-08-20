#!/usr/bin/env python3
"""Focused source-current package evidence checks."""

import sys
import unittest
import hashlib
import struct
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))
import source_current_package_validator as validator  # noqa: E402
import package_inventory  # noqa: E402
from test_release_candidate import ReleaseCandidateTests  # noqa: E402
from test_package_inventory import build_exe  # noqa: E402


class SourceCurrentPackageValidatorTests(unittest.TestCase):
    def setUp(self):
        self.fixture = ReleaseCandidateTests(methodName="test_writes_deterministic_schema_valid_record_and_sums")
        self.fixture.setUp()
        self.record = self.fixture.build()
        # The release-candidate fixture intentionally uses a tiny fake GDPC
        # trailer. Replace only that trailer payload with the valid format-4
        # fixture so this validator exercises the real PCK parser as well.
        valid = build_exe([("assets/fake.bin", b"fake")])
        pck = valid[128:-12]
        prefix = self.fixture.artifact.read_bytes()[:1024]
        rebuilt = prefix + pck + struct.pack("<Q4s", len(pck), b"GDPC")
        self.fixture.artifact.write_bytes(rebuilt)
        base, pack_end = package_inventory.find_pck(rebuilt)
        parsed = package_inventory.parse(rebuilt, base, pack_end)
        self.record["artifact"]["size"] = len(rebuilt)
        self.record["artifact"]["sha256"] = hashlib.sha256(rebuilt).hexdigest()
        self.record["evidence"]["package_inventory"].update(
            pck_offset=parsed["pck"]["offset"],
            pck_size=parsed["pck"]["size"],
            pck_format=parsed["pck"]["format"],
            entry_count=parsed["pck"]["entry_count"],
            path_manifest_sha256=parsed["pck"]["sorted_path_manifest_sha256"],
        )
        self.record_path = self.fixture.evidence / "candidate.release.json"
        self.record_path.write_text(__import__("json").dumps(self.record), encoding="utf-8")

    def tearDown(self):
        self.fixture.tearDown()

    def test_accepts_current_source_and_embedded_package_metadata(self):
        result = validator.validate_source_current(
            self.fixture.repository, self.fixture.artifact, self.record_path
        )
        self.assertEqual(result["status"], "PASS")
        self.assertEqual(result["pck_entry_count"], 1)
        self.assertEqual(result["package_probe_run_id"], "fake-probes")

    def test_rejects_record_from_different_source_revision(self):
        self.record["source"]["revision"] = "0" * 40
        self.record_path.write_text(__import__("json").dumps(self.record), encoding="utf-8")
        with self.assertRaisesRegex(validator.release_candidate.EvidenceError, "revision mismatch"):
            validator.validate_source_current(
                self.fixture.repository, self.fixture.artifact, self.record_path
            )

    def test_rejects_package_metadata_drift(self):
        self.record["evidence"]["package_inventory"]["entry_count"] = 2
        self.record_path.write_text(__import__("json").dumps(self.record), encoding="utf-8")
        with self.assertRaisesRegex(validator.release_candidate.EvidenceError, "PCK entry count mismatch"):
            validator.validate_source_current(
                self.fixture.repository, self.fixture.artifact, self.record_path
            )


if __name__ == "__main__":
    unittest.main()
