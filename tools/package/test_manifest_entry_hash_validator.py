import unittest

from tools.package.manifest_entry_hash_validator import validate_entries


def entries():
    return {
        "schema_version": 1,
        "build_label": "entry-hash-42",
        "manifest_path": "manifest.json",
        "declared_count": 2,
        "entries": [{"path": "game.exe", "sha256": "a" * 64}, {"path": "game.pck", "sha256": "b" * 64}],
        "audit": {"status": "PASS", "evidence": "entry audit", "hashed_count": 2, "missing_hashes": 0},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestEntryHashValidatorTest(unittest.TestCase):
    def test_accepts_complete_entry_hash_manifest(self):
        self.assertEqual(validate_entries(entries()), [])

    def test_rejects_count_and_hash_drift(self):
        item = entries()
        item["declared_count"] = 3
        item["entries"][0]["sha256"] = "bad"
        errors = validate_entries(item)
        self.assertTrue(any("declared_count must equal" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_rejects_duplicate_paths(self):
        item = entries()
        item["entries"][1]["path"] = "game.exe"
        self.assertTrue(any("path must be unique" in error for error in validate_entries(item)))

    def test_native_not_run_cannot_carry_hardware(self):
        item = entries()
        item["native_execution"]["hardware"] = "GPU"
        self.assertTrue(any("hardware must be null" in error for error in validate_entries(item)))


if __name__ == "__main__":
    unittest.main()
