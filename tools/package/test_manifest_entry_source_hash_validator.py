import unittest

from tools.package.manifest_entry_source_hash_validator import validate_entries


def entries():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "entry-source-hash-42",
        "source_commit": commit,
        "entries": [{"path": "game.exe", "source_commit": commit, "sha256": "b" * 64, "evidence": "entry report"}],
        "audit": {"status": "PASS", "evidence": "source/hash audit", "source_matches": True, "hashes_complete": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestEntrySourceHashValidatorTest(unittest.TestCase):
    def test_accepts_source_bound_hashed_entry(self):
        self.assertEqual(validate_entries(entries()), [])

    def test_rejects_entry_source_drift(self):
        item = entries()
        item["entries"][0]["source_commit"] = "c" * 40
        self.assertTrue(any("source_commit must match" in error for error in validate_entries(item)))

    def test_rejects_missing_or_invalid_entry_hash_evidence(self):
        item = entries()
        item["entries"][0]["sha256"] = "bad"
        item["entries"][0]["evidence"] = None
        errors = validate_entries(item)
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))
        self.assertTrue(any("evidence is required" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = entries()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_entries(item)))


if __name__ == "__main__":
    unittest.main()
