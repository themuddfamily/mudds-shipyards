import unittest

from tools.package.source_hash_provenance_v188 import validate_v188


def record():
    common = {"source_id": "source-188", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-188", "package_version": "18.8.0", "source_result_count": 4, "package_result_count": 5}
    return {
        "schema_version": 188, "build_label": "source-provenance-v188", **common, "provenance_id": "provenance-188",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-188", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV188Test(unittest.TestCase):
    def test_accepts_result_counts(self):
        self.assertEqual(validate_v188(record()), [])

    def test_requires_matching_result_counts(self):
        item = record()
        item["source"]["source_result_count"] = 3
        item["provenance"]["package_result_count"] = 6
        errors = validate_v188(item)
        self.assertTrue(any("source.source_result_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_result_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 187
        item["provenance"]["proven"] = False
        errors = validate_v188(item)
        self.assertTrue(any("schema_version must be 188" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v188(item)))


if __name__ == "__main__":
    unittest.main()
