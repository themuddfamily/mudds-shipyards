import unittest

from tools.package.source_hash_provenance_v168 import validate_v168


def record():
    common = {"source_id": "source-168", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-168", "package_version": "16.8.0", "source_branch_count": 2, "package_channel_count": 3}
    return {
        "schema_version": 168, "build_label": "source-provenance-v168", **common, "provenance_id": "provenance-168",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-168", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV168Test(unittest.TestCase):
    def test_accepts_branch_channel_counts(self):
        self.assertEqual(validate_v168(record()), [])

    def test_requires_matching_branch_channel_counts(self):
        item = record()
        item["source"]["source_branch_count"] = 1
        item["provenance"]["package_channel_count"] = 4
        errors = validate_v168(item)
        self.assertTrue(any("source.source_branch_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_channel_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 167
        item["provenance"]["proven"] = False
        errors = validate_v168(item)
        self.assertTrue(any("schema_version must be 168" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v168(item)))


if __name__ == "__main__":
    unittest.main()
