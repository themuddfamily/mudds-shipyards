import unittest

from tools.package.manifest_path_normalization_validator import validate_paths


def paths():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "normalize-42",
        "source_commit": commit,
        "entries": [{"raw_path": r"bin\\game.exe", "canonical_path": "bin/game.exe", "sha256": "b" * 64, "source_commit": commit}],
        "audit": {"status": "PASS", "evidence": "normalization audit", "normalized": True, "hashes_complete": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestPathNormalizationValidatorTest(unittest.TestCase):
    def test_accepts_normalized_relative_hashed_entry(self):
        self.assertEqual(validate_paths(paths()), [])

    def test_rejects_noncanonical_path(self):
        item = paths()
        item["entries"][0]["canonical_path"] = "../game.exe"
        self.assertTrue(any("normalized relative path" in error for error in validate_paths(item)))

    def test_rejects_hash_or_source_drift(self):
        item = paths()
        item["entries"][0]["sha256"] = "bad"
        item["entries"][0]["source_commit"] = "c" * 40
        errors = validate_paths(item)
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))
        self.assertTrue(any("source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = paths()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_paths(item)))


if __name__ == "__main__":
    unittest.main()
