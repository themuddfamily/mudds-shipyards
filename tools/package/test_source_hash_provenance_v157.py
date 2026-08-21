import unittest

from tools.package.source_hash_provenance_v157 import validate_v157


def record():
    common = {"source_id": "source-157", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-157", "package_version": "15.7.0", "source_license_count": 2, "package_license_count": 3}
    return {
        "schema_version": 157, "build_label": "source-provenance-v157", **common, "provenance_id": "provenance-157",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-157", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV157Test(unittest.TestCase):
    def test_accepts_license_counts(self):
        self.assertEqual(validate_v157(record()), [])

    def test_requires_matching_license_counts(self):
        item = record()
        item["source"]["source_license_count"] = 1
        item["provenance"]["package_license_count"] = 4
        errors = validate_v157(item)
        self.assertTrue(any("source.source_license_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_license_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 156
        item["provenance"]["proven"] = False
        errors = validate_v157(item)
        self.assertTrue(any("schema_version must be 157" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v157(item)))


if __name__ == "__main__":
    unittest.main()
