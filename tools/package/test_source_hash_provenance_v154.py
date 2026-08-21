import unittest

from tools.package.source_hash_provenance_v154 import validate_v154


def record():
    common = {"source_id": "source-154", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-154", "package_version": "15.4.0", "source_path_count": 21, "package_file_count": 14}
    return {
        "schema_version": 154, "build_label": "source-provenance-v154", **common, "provenance_id": "provenance-154",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-154", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV154Test(unittest.TestCase):
    def test_accepts_path_file_counts(self):
        self.assertEqual(validate_v154(record()), [])

    def test_requires_matching_path_file_counts(self):
        item = record()
        item["source"]["source_path_count"] = 20
        item["provenance"]["package_file_count"] = 15
        errors = validate_v154(item)
        self.assertTrue(any("source.source_path_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_file_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 153
        item["provenance"]["proven"] = False
        errors = validate_v154(item)
        self.assertTrue(any("schema_version must be 154" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "runtime.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v154(item)))


if __name__ == "__main__":
    unittest.main()
