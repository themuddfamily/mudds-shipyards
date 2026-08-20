import unittest

from tools.package.manifest_normalized_count_validator import validate_counts


def counts():
    return {
        "schema_version": 1,
        "build_label": "normalized-count-42",
        "source_commit": "a" * 40,
        "entries": [{"canonical_path": "game.exe", "sha256": "b" * 64}, {"canonical_path": "game.pck", "sha256": "c" * 64}],
        "declared_count": 2,
        "observed_count": 2,
        "normalized_count": 2,
        "hashed_count": 2,
        "audit": {"status": "PASS", "evidence": "count audit", "counts_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestNormalizedCountValidatorTest(unittest.TestCase):
    def test_accepts_matching_normalized_hash_counts(self):
        self.assertEqual(validate_counts(counts()), [])

    def test_rejects_count_drift(self):
        item = counts()
        item["hashed_count"] = 1
        self.assertTrue(any("hashed_count must equal" in error for error in validate_counts(item)))

    def test_rejects_duplicate_paths_or_bad_hash(self):
        item = counts()
        item["entries"][1]["canonical_path"] = "game.exe"
        item["entries"][0]["sha256"] = "bad"
        errors = validate_counts(item)
        self.assertTrue(any("canonical_path must be unique" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = counts()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_counts(item)))


if __name__ == "__main__":
    unittest.main()
