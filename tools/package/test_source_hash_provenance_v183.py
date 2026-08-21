import unittest

from tools.package.source_hash_provenance_v183 import validate_v183


def record():
    common = {"source_id": "source-183", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-183", "package_version": "18.3.0", "source_checksum_count": 3, "package_checksum_count": 4}
    return {
        "schema_version": 183, "build_label": "source-provenance-v183", **common, "provenance_id": "provenance-183",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-183", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV183Test(unittest.TestCase):
    def test_accepts_checksum_counts(self):
        self.assertEqual(validate_v183(record()), [])

    def test_requires_matching_checksum_counts(self):
        item = record()
        item["source"]["source_checksum_count"] = 2
        item["provenance"]["package_checksum_count"] = 5
        errors = validate_v183(item)
        self.assertTrue(any("source.source_checksum_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_checksum_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 182
        item["provenance"]["proven"] = False
        errors = validate_v183(item)
        self.assertTrue(any("schema_version must be 183" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v183(item)))


if __name__ == "__main__":
    unittest.main()
