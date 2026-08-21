import unittest

from tools.package.source_hash_provenance_v243 import validate_v243


def record():
    common = {"source_id": "source-243", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-243", "package_version": "24.3.0", "source_certified_count": 1, "package_certified_count": 2}
    return {"schema_version": 243, "build_label": "source-provenance-v243", **common, "provenance_id": "provenance-243", "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True}, "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-243", **common, "proven": True}, "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None}}


class SourceHashProvenanceV243Test(unittest.TestCase):
    def test_accepts_certified_counts(self):
        self.assertEqual(validate_v243(record()), [])

    def test_requires_matching_certified_counts(self):
        item = record()
        item["source"]["source_certified_count"] = 0
        item["provenance"]["package_certified_count"] = 3
        errors = validate_v243(item)
        self.assertTrue(any("source.source_certified_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_certified_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 242
        item["provenance"]["proven"] = False
        errors = validate_v243(item)
        self.assertTrue(any("schema_version must be 243" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v243(item)))


if __name__ == "__main__":
    unittest.main()
