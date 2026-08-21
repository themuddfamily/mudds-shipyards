import unittest

from tools.package.source_hash_provenance_v173 import validate_v173


def record():
    common = {"source_id": "source-173", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-173", "package_version": "17.3.0", "source_line_count": 101, "package_line_count": 202}
    return {
        "schema_version": 173, "build_label": "source-provenance-v173", **common, "provenance_id": "provenance-173",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-173", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV173Test(unittest.TestCase):
    def test_accepts_line_counts(self):
        self.assertEqual(validate_v173(record()), [])

    def test_requires_matching_line_counts(self):
        item = record()
        item["source"]["source_line_count"] = 100
        item["provenance"]["package_line_count"] = 203
        errors = validate_v173(item)
        self.assertTrue(any("source.source_line_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_line_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 172
        item["provenance"]["proven"] = False
        errors = validate_v173(item)
        self.assertTrue(any("schema_version must be 173" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v173(item)))


if __name__ == "__main__":
    unittest.main()
