import unittest

from tools.package.manifest_digest_count_rollup_validator import validate_rollup


def rollup():
    digest = "a" * 64
    return {
        "schema_version": 1,
        "build_label": "digest-count-42",
        "manifest_path": "manifest.json",
        "manifest_sha256": digest,
        "entry_count": 2,
        "observed_entry_count": 2,
        "digest_check": {"status": "PASS", "evidence": "digest log", "computed_sha256": digest},
        "count_check": {"status": "PASS", "evidence": "count log", "matches": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ManifestDigestCountRollupValidatorTest(unittest.TestCase):
    def test_accepts_matching_digest_and_counts(self):
        self.assertEqual(validate_rollup(rollup()), [])

    def test_rejects_digest_drift(self):
        item = rollup()
        item["digest_check"]["computed_sha256"] = "b" * 64
        self.assertTrue(any("computed_sha256 must match" in error for error in validate_rollup(item)))

    def test_rejects_count_drift_or_failed_count_flag(self):
        item = rollup()
        item["observed_entry_count"] = 3
        item["count_check"]["matches"] = False
        errors = validate_rollup(item)
        self.assertTrue(any("entry_count must equal" in error for error in errors))
        self.assertTrue(any("matches must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = rollup()
        item["native_execution"]["hardware"] = "GPU"
        self.assertTrue(any("hardware must be null" in error for error in validate_rollup(item)))


if __name__ == "__main__":
    unittest.main()
