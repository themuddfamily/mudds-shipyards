import unittest

from tools.package.normalized_source_hash_completeness_validator import validate_completeness


def completeness():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "build_label": "completeness-42",
        "source_commit": commit,
        "aggregate_sha256": "b" * 64,
        "entries": [{"normalized_path": "game.exe", "source_commit": commit, "sha256": "c" * 64}],
        "coverage": {"status": "PASS", "evidence": "coverage audit", "all_paths_accounted": True, "all_sources_bound": True, "all_hashes_present": True, "missing_paths": 0, "missing_hashes": 0},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class NormalizedSourceHashCompletenessValidatorTest(unittest.TestCase):
    def test_accepts_complete_coverage(self):
        self.assertEqual(validate_completeness(completeness()), [])

    def test_rejects_missing_coverage(self):
        item = completeness()
        item["coverage"]["missing_hashes"] = 1
        self.assertTrue(any("missing_paths and missing_hashes must be 0" in error for error in validate_completeness(item)))

    def test_rejects_source_or_hash_entry_drift(self):
        item = completeness()
        item["entries"][0]["source_commit"] = "d" * 40
        item["entries"][0]["sha256"] = "bad"
        errors = validate_completeness(item)
        self.assertTrue(any("source_commit must match" in error for error in errors))
        self.assertTrue(any("sha256 must be a 64-character" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = completeness()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_completeness(item)))


if __name__ == "__main__":
    unittest.main()
