import unittest

from tools.package.source_hash_provenance_v192 import validate_v192


def record():
    common = {"source_id": "source-192", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-192", "package_version": "19.2.0", "source_assertion_count": 3, "package_assertion_count": 4}
    return {
        "schema_version": 192, "build_label": "source-provenance-v192", **common, "provenance_id": "provenance-192",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-192", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV192Test(unittest.TestCase):
    def test_accepts_assertion_counts(self):
        self.assertEqual(validate_v192(record()), [])

    def test_requires_matching_assertion_counts(self):
        item = record()
        item["source"]["source_assertion_count"] = 2
        item["provenance"]["package_assertion_count"] = 5
        errors = validate_v192(item)
        self.assertTrue(any("source.source_assertion_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_assertion_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 191
        item["provenance"]["proven"] = False
        errors = validate_v192(item)
        self.assertTrue(any("schema_version must be 192" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v192(item)))


if __name__ == "__main__":
    unittest.main()
