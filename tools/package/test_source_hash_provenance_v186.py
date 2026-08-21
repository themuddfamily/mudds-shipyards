import unittest

from tools.package.source_hash_provenance_v186 import validate_v186


def record():
    common = {"source_id": "source-186", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-186", "package_version": "18.6.0", "source_state_count": 3, "package_state_count": 4}
    return {
        "schema_version": 186, "build_label": "source-provenance-v186", **common, "provenance_id": "provenance-186",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-186", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV186Test(unittest.TestCase):
    def test_accepts_state_counts(self):
        self.assertEqual(validate_v186(record()), [])

    def test_requires_matching_state_counts(self):
        item = record()
        item["source"]["source_state_count"] = 2
        item["provenance"]["package_state_count"] = 5
        errors = validate_v186(item)
        self.assertTrue(any("source.source_state_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_state_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 185
        item["provenance"]["proven"] = False
        errors = validate_v186(item)
        self.assertTrue(any("schema_version must be 186" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v186(item)))


if __name__ == "__main__":
    unittest.main()
