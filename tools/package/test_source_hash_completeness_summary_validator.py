import unittest

from tools.package.source_hash_completeness_summary_validator import validate_summary


def summary():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "summary-42",
        "source_commit": commit,
        "summary_digest": "b" * 64,
        "entries": [{"source_commit": commit, "sha256": "c" * 64}],
        "total_entries": 1,
        "source_bound_entries": 1,
        "hashed_entries": 1,
        "summary_check": {"status": "PASS", "evidence": "summary report", "complete": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashCompletenessSummaryValidatorTest(unittest.TestCase):
    def test_accepts_complete_summary(self):
        self.assertEqual(validate_summary(summary()), [])

    def test_rejects_summary_count_drift(self):
        item = summary()
        item["hashed_entries"] = 0
        self.assertTrue(any("hashed_entries must equal" in error for error in validate_summary(item)))

    def test_rejects_source_or_hash_entry_drift(self):
        item = summary()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][0]["sha256"] = "bad"
        errors = validate_summary(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = summary()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_summary(item)))


if __name__ == "__main__":
    unittest.main()
