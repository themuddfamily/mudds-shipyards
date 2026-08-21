import unittest

from tools.package.source_hash_provenance_v205 import validate_v205


def record():
    common = {"source_id": "source-205", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-205", "package_version": "20.5.0", "source_unknown_count": 1, "package_unknown_count": 2}
    return {
        "schema_version": 205, "build_label": "source-provenance-v205", **common, "provenance_id": "provenance-205",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-205", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV205Test(unittest.TestCase):
    def test_accepts_unknown_counts(self):
        self.assertEqual(validate_v205(record()), [])

    def test_requires_matching_unknown_counts(self):
        item = record()
        item["source"]["source_unknown_count"] = 0
        item["provenance"]["package_unknown_count"] = 3
        errors = validate_v205(item)
        self.assertTrue(any("source.source_unknown_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_unknown_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 204
        item["provenance"]["proven"] = False
        errors = validate_v205(item)
        self.assertTrue(any("schema_version must be 205" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v205(item)))


if __name__ == "__main__":
    unittest.main()
