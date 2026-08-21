import unittest

from tools.package.source_hash_provenance_v189 import validate_v189


def record():
    common = {"source_id": "source-189", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-189", "package_version": "18.9.0", "source_check_count": 3, "package_check_count": 4}
    return {
        "schema_version": 189, "build_label": "source-provenance-v189", **common, "provenance_id": "provenance-189",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-189", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV189Test(unittest.TestCase):
    def test_accepts_check_counts(self):
        self.assertEqual(validate_v189(record()), [])

    def test_requires_matching_check_counts(self):
        item = record()
        item["source"]["source_check_count"] = 2
        item["provenance"]["package_check_count"] = 5
        errors = validate_v189(item)
        self.assertTrue(any("source.source_check_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_check_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 188
        item["provenance"]["proven"] = False
        errors = validate_v189(item)
        self.assertTrue(any("schema_version must be 189" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v189(item)))


if __name__ == "__main__":
    unittest.main()
