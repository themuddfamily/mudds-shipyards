import unittest

from tools.package.source_hash_provenance_v179 import validate_v179


def record():
    common = {"source_id": "source-179", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-179", "package_version": "17.9.0", "source_item_count": 6, "package_item_count": 7}
    return {
        "schema_version": 179, "build_label": "source-provenance-v179", **common, "provenance_id": "provenance-179",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-179", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV179Test(unittest.TestCase):
    def test_accepts_item_counts(self):
        self.assertEqual(validate_v179(record()), [])

    def test_requires_matching_item_counts(self):
        item = record()
        item["source"]["source_item_count"] = 5
        item["provenance"]["package_item_count"] = 8
        errors = validate_v179(item)
        self.assertTrue(any("source.source_item_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_item_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 178
        item["provenance"]["proven"] = False
        errors = validate_v179(item)
        self.assertTrue(any("schema_version must be 179" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v179(item)))


if __name__ == "__main__":
    unittest.main()
