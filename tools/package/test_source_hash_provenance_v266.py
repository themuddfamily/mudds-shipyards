import unittest

from tools.package.source_hash_provenance_v266 import validate_v266


def record():
    common = {"source_id": "source-266", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-266", "package_version": "26.6.0", "source_inspected_count": 1, "package_inspected_count": 2}
    return {"schema_version": 266, "build_label": "source-provenance-v266", **common, "provenance_id": "provenance-266", "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True}, "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-266", **common, "proven": True}, "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None}}


class SourceHashProvenanceV266Test(unittest.TestCase):
    def test_accepts_inspected_counts(self):
        self.assertEqual(validate_v266(record()), [])

    def test_requires_matching_inspected_counts(self):
        item = record()
        item["source"]["source_inspected_count"] = 0
        item["provenance"]["package_inspected_count"] = 3
        errors = validate_v266(item)
        self.assertTrue(any("source.source_inspected_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_inspected_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 265
        item["provenance"]["proven"] = False
        errors = validate_v266(item)
        self.assertTrue(any("schema_version must be 266" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v266(item)))


if __name__ == "__main__":
    unittest.main()
