import unittest

from tools.package.manifest_normalized_source_hash_count import validate_rollup


def rollup():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "source-hash-count-42",
        "source_commit": commit,
        "entries": [{"normalized_path": "game.exe", "source_commit": commit, "sha256": "b" * 64}, {"normalized_path": "game.pck", "source_commit": commit, "sha256": "c" * 64}],
        "declared_count": 2,
        "normalized_count": 2,
        "source_bound_count": 2,
        "hashed_count": 2,
        "audit": {"status": "PASS", "evidence": "count audit", "counts_match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestNormalizedSourceHashCountTest(unittest.TestCase):
    def test_accepts_matching_source_hash_counts(self):
        self.assertEqual(validate_rollup(rollup()), [])

    def test_rejects_source_or_hash_drift(self):
        item = rollup()
        item["entries"][0]["source_commit"] = "c" * 40
        item["entries"][1]["sha256"] = "bad"
        errors = validate_rollup(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_rejects_count_drift(self):
        item = rollup()
        item["source_bound_count"] = 1
        self.assertTrue(any("source_bound_count must equal" in error for error in validate_rollup(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = rollup()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_rollup(item)))


if __name__ == "__main__":
    unittest.main()
