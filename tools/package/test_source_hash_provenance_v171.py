import unittest

from tools.package.source_hash_provenance_v171 import validate_v171


def record():
    common = {"source_id": "source-171", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-171", "package_version": "17.1.0", "source_commit_count": 3, "package_commit_count": 4}
    return {
        "schema_version": 171, "build_label": "source-provenance-v171", **common, "provenance_id": "provenance-171",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-171", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV171Test(unittest.TestCase):
    def test_accepts_commit_counts(self):
        self.assertEqual(validate_v171(record()), [])

    def test_requires_matching_commit_counts(self):
        item = record()
        item["source"]["source_commit_count"] = 2
        item["provenance"]["package_commit_count"] = 5
        errors = validate_v171(item)
        self.assertTrue(any("source.source_commit_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_commit_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 170
        item["provenance"]["proven"] = False
        errors = validate_v171(item)
        self.assertTrue(any("schema_version must be 171" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v171(item)))


if __name__ == "__main__":
    unittest.main()
