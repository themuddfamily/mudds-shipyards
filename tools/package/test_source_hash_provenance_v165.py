import unittest

from tools.package.source_hash_provenance_v165 import validate_v165


def record():
    common = {"source_id": "source-165", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-165", "package_version": "16.5.0", "source_metadata_count": 5, "package_metadata_count": 6}
    return {
        "schema_version": 165, "build_label": "source-provenance-v165", **common, "provenance_id": "provenance-165",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-165", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV165Test(unittest.TestCase):
    def test_accepts_metadata_counts(self):
        self.assertEqual(validate_v165(record()), [])

    def test_requires_matching_metadata_counts(self):
        item = record()
        item["source"]["source_metadata_count"] = 4
        item["provenance"]["package_metadata_count"] = 7
        errors = validate_v165(item)
        self.assertTrue(any("source.source_metadata_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_metadata_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 164
        item["provenance"]["proven"] = False
        errors = validate_v165(item)
        self.assertTrue(any("schema_version must be 165" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v165(item)))


if __name__ == "__main__":
    unittest.main()
