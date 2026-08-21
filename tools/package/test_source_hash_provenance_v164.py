import unittest

from tools.package.source_hash_provenance_v164 import validate_v164


def record():
    common = {"source_id": "source-164", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-164", "package_version": "16.4.0", "source_field_count": 9, "package_field_count": 10}
    return {
        "schema_version": 164, "build_label": "source-provenance-v164", **common, "provenance_id": "provenance-164",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-164", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV164Test(unittest.TestCase):
    def test_accepts_field_counts(self):
        self.assertEqual(validate_v164(record()), [])

    def test_requires_matching_field_counts(self):
        item = record()
        item["source"]["source_field_count"] = 8
        item["provenance"]["package_field_count"] = 11
        errors = validate_v164(item)
        self.assertTrue(any("source.source_field_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_field_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 163
        item["provenance"]["proven"] = False
        errors = validate_v164(item)
        self.assertTrue(any("schema_version must be 164" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v164(item)))


if __name__ == "__main__":
    unittest.main()
