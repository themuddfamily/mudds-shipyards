import unittest

from tools.package.source_hash_provenance_v180 import validate_v180


def record():
    common = {"source_id": "source-180", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-180", "package_version": "18.0.0", "source_entry_count": 8, "package_entry_count": 9}
    return {
        "schema_version": 180, "build_label": "source-provenance-v180", **common, "provenance_id": "provenance-180",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-180", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV180Test(unittest.TestCase):
    def test_accepts_entry_counts(self):
        self.assertEqual(validate_v180(record()), [])

    def test_requires_matching_entry_counts(self):
        item = record()
        item["source"]["source_entry_count"] = 7
        item["provenance"]["package_entry_count"] = 10
        errors = validate_v180(item)
        self.assertTrue(any("source.source_entry_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_entry_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 179
        item["provenance"]["proven"] = False
        errors = validate_v180(item)
        self.assertTrue(any("schema_version must be 180" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v180(item)))


if __name__ == "__main__":
    unittest.main()
