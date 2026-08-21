import unittest

from tools.package.source_hash_provenance_v166 import validate_v166


def record():
    common = {"source_id": "source-166", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-166", "package_version": "16.6.0", "source_flag_count": 4, "package_flag_count": 5}
    return {
        "schema_version": 166, "build_label": "source-provenance-v166", **common, "provenance_id": "provenance-166",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-166", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV166Test(unittest.TestCase):
    def test_accepts_flag_counts(self):
        self.assertEqual(validate_v166(record()), [])

    def test_requires_matching_flag_counts(self):
        item = record()
        item["source"]["source_flag_count"] = 3
        item["provenance"]["package_flag_count"] = 6
        errors = validate_v166(item)
        self.assertTrue(any("source.source_flag_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_flag_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 165
        item["provenance"]["proven"] = False
        errors = validate_v166(item)
        self.assertTrue(any("schema_version must be 166" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v166(item)))


if __name__ == "__main__":
    unittest.main()
