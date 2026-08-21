import unittest

from tools.package.source_hash_provenance_v176 import validate_v176


def record():
    common = {"source_id": "source-176", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-176", "package_version": "17.6.0", "source_digest_count": 3, "package_digest_count": 4}
    return {
        "schema_version": 176, "build_label": "source-provenance-v176", **common, "provenance_id": "provenance-176",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-176", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV176Test(unittest.TestCase):
    def test_accepts_digest_counts(self):
        self.assertEqual(validate_v176(record()), [])

    def test_requires_matching_digest_counts(self):
        item = record()
        item["source"]["source_digest_count"] = 2
        item["provenance"]["package_digest_count"] = 5
        errors = validate_v176(item)
        self.assertTrue(any("source.source_digest_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_digest_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 175
        item["provenance"]["proven"] = False
        errors = validate_v176(item)
        self.assertTrue(any("schema_version must be 176" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v176(item)))


if __name__ == "__main__":
    unittest.main()
