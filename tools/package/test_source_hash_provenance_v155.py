import unittest

from tools.package.source_hash_provenance_v155 import validate_v155


def record():
    common = {"source_id": "source-155", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-155", "package_version": "15.5.0", "source_module_count": 11, "package_module_count": 9}
    return {
        "schema_version": 155, "build_label": "source-provenance-v155", **common, "provenance_id": "provenance-155",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-155", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV155Test(unittest.TestCase):
    def test_accepts_module_counts(self):
        self.assertEqual(validate_v155(record()), [])

    def test_requires_matching_module_counts(self):
        item = record()
        item["source"]["source_module_count"] = 10
        item["provenance"]["package_module_count"] = 10
        errors = validate_v155(item)
        self.assertTrue(any("source.source_module_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_module_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 154
        item["provenance"]["proven"] = False
        errors = validate_v155(item)
        self.assertTrue(any("schema_version must be 155" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v155(item)))


if __name__ == "__main__":
    unittest.main()
