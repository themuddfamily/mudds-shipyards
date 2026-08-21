import unittest

from tools.package.source_hash_provenance_v211 import validate_v211


def record():
    common = {"source_id": "source-211", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-211", "package_version": "21.1.0", "source_retry_count": 1, "package_retry_count": 2}
    return {"schema_version": 211, "build_label": "source-provenance-v211", **common, "provenance_id": "provenance-211", "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True}, "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-211", **common, "proven": True}, "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None}}


class SourceHashProvenanceV211Test(unittest.TestCase):
    def test_accepts_retry_counts(self):
        self.assertEqual(validate_v211(record()), [])

    def test_requires_matching_retry_counts(self):
        item = record()
        item["source"]["source_retry_count"] = 0
        item["provenance"]["package_retry_count"] = 3
        errors = validate_v211(item)
        self.assertTrue(any("source.source_retry_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_retry_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 210
        item["provenance"]["proven"] = False
        errors = validate_v211(item)
        self.assertTrue(any("schema_version must be 211" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v211(item)))


if __name__ == "__main__":
    unittest.main()
