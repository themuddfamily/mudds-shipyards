import unittest

from tools.package.source_hash_provenance_v248 import validate_v248


def record():
    common = {"source_id": "source-248", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-248", "package_version": "24.8.0", "source_suppressed_count": 1, "package_suppressed_count": 2}
    return {"schema_version": 248, "build_label": "source-provenance-v248", **common, "provenance_id": "provenance-248", "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True}, "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-248", **common, "proven": True}, "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None}}


class SourceHashProvenanceV248Test(unittest.TestCase):
    def test_accepts_suppressed_counts(self):
        self.assertEqual(validate_v248(record()), [])

    def test_requires_matching_suppressed_counts(self):
        item = record()
        item["source"]["source_suppressed_count"] = 0
        item["provenance"]["package_suppressed_count"] = 3
        errors = validate_v248(item)
        self.assertTrue(any("source.source_suppressed_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_suppressed_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 247
        item["provenance"]["proven"] = False
        errors = validate_v248(item)
        self.assertTrue(any("schema_version must be 248" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v248(item)))


if __name__ == "__main__":
    unittest.main()
