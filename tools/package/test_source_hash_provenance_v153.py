import unittest

from tools.package.source_hash_provenance_v153 import validate_v153


def record():
    common = {"source_id": "source-153", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-153", "package_version": "15.3.0", "source_artifact_count": 8, "package_entry_count": 12}
    return {
        "schema_version": 153, "build_label": "source-provenance-v153", **common, "provenance_id": "provenance-153",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-153", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV153Test(unittest.TestCase):
    def test_accepts_artifact_entry_counts(self):
        self.assertEqual(validate_v153(record()), [])

    def test_requires_matching_artifact_entry_counts(self):
        item = record()
        item["source"]["source_artifact_count"] = 7
        item["provenance"]["package_entry_count"] = 13
        errors = validate_v153(item)
        self.assertTrue(any("source.source_artifact_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_entry_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 152
        item["provenance"]["proven"] = False
        errors = validate_v153(item)
        self.assertTrue(any("schema_version must be 153" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v153(item)))


if __name__ == "__main__":
    unittest.main()
