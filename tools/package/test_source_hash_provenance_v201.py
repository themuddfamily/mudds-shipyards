import unittest

from tools.package.source_hash_provenance_v201 import validate_v201


def record():
    common = {"source_id": "source-201", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-201", "package_version": "20.1.0", "source_warning_count": 1, "package_warning_count": 2}
    return {
        "schema_version": 201, "build_label": "source-provenance-v201", **common, "provenance_id": "provenance-201",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-201", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV201Test(unittest.TestCase):
    def test_accepts_warning_counts(self):
        self.assertEqual(validate_v201(record()), [])

    def test_requires_matching_warning_counts(self):
        item = record()
        item["source"]["source_warning_count"] = 0
        item["provenance"]["package_warning_count"] = 3
        errors = validate_v201(item)
        self.assertTrue(any("source.source_warning_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_warning_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 200
        item["provenance"]["proven"] = False
        errors = validate_v201(item)
        self.assertTrue(any("schema_version must be 201" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v201(item)))


if __name__ == "__main__":
    unittest.main()
