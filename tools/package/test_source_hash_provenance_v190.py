import unittest

from tools.package.source_hash_provenance_v190 import validate_v190


def record():
    common = {"source_id": "source-190", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-190", "package_version": "19.0.0", "source_test_count": 5, "package_test_count": 6}
    return {
        "schema_version": 190, "build_label": "source-provenance-v190", **common, "provenance_id": "provenance-190",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-190", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV190Test(unittest.TestCase):
    def test_accepts_test_counts(self):
        self.assertEqual(validate_v190(record()), [])

    def test_requires_matching_test_counts(self):
        item = record()
        item["source"]["source_test_count"] = 4
        item["provenance"]["package_test_count"] = 7
        errors = validate_v190(item)
        self.assertTrue(any("source.source_test_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_test_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 189
        item["provenance"]["proven"] = False
        errors = validate_v190(item)
        self.assertTrue(any("schema_version must be 190" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v190(item)))


if __name__ == "__main__":
    unittest.main()
