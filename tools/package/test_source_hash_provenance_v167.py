import unittest

from tools.package.source_hash_provenance_v167 import validate_v167


def record():
    common = {"source_id": "source-167", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-167", "package_version": "16.7.0", "source_tag_count": 3, "package_tag_count": 4}
    return {
        "schema_version": 167, "build_label": "source-provenance-v167", **common, "provenance_id": "provenance-167",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-167", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV167Test(unittest.TestCase):
    def test_accepts_tag_counts(self):
        self.assertEqual(validate_v167(record()), [])

    def test_requires_matching_tag_counts(self):
        item = record()
        item["source"]["source_tag_count"] = 2
        item["provenance"]["package_tag_count"] = 5
        errors = validate_v167(item)
        self.assertTrue(any("source.source_tag_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_tag_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 166
        item["provenance"]["proven"] = False
        errors = validate_v167(item)
        self.assertTrue(any("schema_version must be 167" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v167(item)))


if __name__ == "__main__":
    unittest.main()
