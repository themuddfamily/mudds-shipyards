import unittest

from tools.package.normalized_source_hash_aggregate_validator import validate_aggregate


def aggregate():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "aggregate-42",
        "source_commit": commit,
        "aggregate_sha256": "b" * 64,
        "aggregate_count": 1,
        "entries": [{"normalized_path": "game.exe", "source_commit": commit, "sha256": "c" * 64}],
        "audit": {"status": "PASS", "evidence": "aggregate report", "source_bound": True, "hashes_complete": True, "aggregate_matches": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class NormalizedSourceHashAggregateValidatorTest(unittest.TestCase):
    def test_accepts_complete_aggregate(self):
        self.assertEqual(validate_aggregate(aggregate()), [])

    def test_rejects_aggregate_count_drift(self):
        item = aggregate()
        item["aggregate_count"] = 2
        self.assertTrue(any("aggregate_count must equal" in error for error in validate_aggregate(item)))

    def test_rejects_source_or_hash_entry_drift(self):
        item = aggregate()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][0]["sha256"] = "bad"
        errors = validate_aggregate(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = aggregate()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_aggregate(item)))


if __name__ == "__main__":
    unittest.main()
