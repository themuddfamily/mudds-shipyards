import unittest

from tools.package.source_hash_provenance_v195 import validate_v195


def record():
    common = {"source_id": "source-195", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-195", "package_version": "19.5.0", "source_api_count": 5, "package_api_count": 6}
    return {
        "schema_version": 195, "build_label": "source-provenance-v195", **common, "provenance_id": "provenance-195",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-195", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV195Test(unittest.TestCase):
    def test_accepts_api_counts(self):
        self.assertEqual(validate_v195(record()), [])

    def test_requires_matching_api_counts(self):
        item = record()
        item["source"]["source_api_count"] = 4
        item["provenance"]["package_api_count"] = 7
        errors = validate_v195(item)
        self.assertTrue(any("source.source_api_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_api_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 194
        item["provenance"]["proven"] = False
        errors = validate_v195(item)
        self.assertTrue(any("schema_version must be 195" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v195(item)))


if __name__ == "__main__":
    unittest.main()
