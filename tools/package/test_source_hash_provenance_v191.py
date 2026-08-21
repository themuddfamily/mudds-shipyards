import unittest

from tools.package.source_hash_provenance_v191 import validate_v191


def record():
    common = {"source_id": "source-191", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-191", "package_version": "19.1.0", "source_test_case_count": 7, "package_test_case_count": 8}
    return {
        "schema_version": 191, "build_label": "source-provenance-v191", **common, "provenance_id": "provenance-191",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-191", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV191Test(unittest.TestCase):
    def test_accepts_test_case_counts(self):
        self.assertEqual(validate_v191(record()), [])

    def test_requires_matching_test_case_counts(self):
        item = record()
        item["source"]["source_test_case_count"] = 6
        item["provenance"]["package_test_case_count"] = 9
        errors = validate_v191(item)
        self.assertTrue(any("source.source_test_case_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_test_case_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 190
        item["provenance"]["proven"] = False
        errors = validate_v191(item)
        self.assertTrue(any("schema_version must be 191" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v191(item)))


if __name__ == "__main__":
    unittest.main()
