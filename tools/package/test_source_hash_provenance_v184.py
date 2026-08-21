import unittest

from tools.package.source_hash_provenance_v184 import validate_v184


def record():
    common = {"source_id": "source-184", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-184", "package_version": "18.4.0", "source_digest_algorithm_count": 1, "package_digest_algorithm_count": 2}
    return {
        "schema_version": 184, "build_label": "source-provenance-v184", **common, "provenance_id": "provenance-184",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-184", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV184Test(unittest.TestCase):
    def test_accepts_digest_algorithm_counts(self):
        self.assertEqual(validate_v184(record()), [])

    def test_requires_matching_digest_algorithm_counts(self):
        item = record()
        item["source"]["source_digest_algorithm_count"] = 0
        item["provenance"]["package_digest_algorithm_count"] = 3
        errors = validate_v184(item)
        self.assertTrue(any("source.source_digest_algorithm_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_digest_algorithm_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 183
        item["provenance"]["proven"] = False
        errors = validate_v184(item)
        self.assertTrue(any("schema_version must be 184" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v184(item)))


if __name__ == "__main__":
    unittest.main()
