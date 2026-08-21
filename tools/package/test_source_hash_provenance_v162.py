import unittest

from tools.package.source_hash_provenance_v162 import validate_v162


def record():
    common = {"source_id": "source-162", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-162", "package_version": "16.2.0", "source_key_count": 7, "package_key_count": 8}
    return {
        "schema_version": 162, "build_label": "source-provenance-v162", **common, "provenance_id": "provenance-162",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-162", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV162Test(unittest.TestCase):
    def test_accepts_key_counts(self):
        self.assertEqual(validate_v162(record()), [])

    def test_requires_matching_key_counts(self):
        item = record()
        item["source"]["source_key_count"] = 6
        item["provenance"]["package_key_count"] = 9
        errors = validate_v162(item)
        self.assertTrue(any("source.source_key_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_key_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 161
        item["provenance"]["proven"] = False
        errors = validate_v162(item)
        self.assertTrue(any("schema_version must be 162" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v162(item)))


if __name__ == "__main__":
    unittest.main()
