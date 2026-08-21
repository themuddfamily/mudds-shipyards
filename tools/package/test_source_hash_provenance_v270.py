import unittest

from tools.package.source_hash_provenance_v270 import validate_v270


def record():
    common = {"source_id": "source-270", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-270", "package_version": "27.0.0", "source_reconciled_count": 1, "package_reconciled_count": 2}
    return {"schema_version": 270, "build_label": "source-provenance-v270", **common, "provenance_id": "provenance-270", "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True}, "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-270", **common, "proven": True}, "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None}}


class SourceHashProvenanceV270Test(unittest.TestCase):
    def test_accepts_reconciled_counts(self):
        self.assertEqual(validate_v270(record()), [])

    def test_requires_matching_reconciled_counts(self):
        item = record()
        item["source"]["source_reconciled_count"] = 0
        item["provenance"]["package_reconciled_count"] = 3
        errors = validate_v270(item)
        self.assertTrue(any("source.source_reconciled_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_reconciled_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 269
        item["provenance"]["proven"] = False
        errors = validate_v270(item)
        self.assertTrue(any("schema_version must be 270" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v270(item)))


if __name__ == "__main__":
    unittest.main()
