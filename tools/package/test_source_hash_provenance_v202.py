import unittest

from tools.package.source_hash_provenance_v202 import validate_v202


def record():
    common = {"source_id": "source-202", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-202", "package_version": "20.2.0", "source_error_count": 1, "package_error_count": 2}
    return {
        "schema_version": 202, "build_label": "source-provenance-v202", **common, "provenance_id": "provenance-202",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-202", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV202Test(unittest.TestCase):
    def test_accepts_error_counts(self):
        self.assertEqual(validate_v202(record()), [])

    def test_requires_matching_error_counts(self):
        item = record()
        item["source"]["source_error_count"] = 0
        item["provenance"]["package_error_count"] = 3
        errors = validate_v202(item)
        self.assertTrue(any("source.source_error_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_error_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 201
        item["provenance"]["proven"] = False
        errors = validate_v202(item)
        self.assertTrue(any("schema_version must be 202" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v202(item)))


if __name__ == "__main__":
    unittest.main()
