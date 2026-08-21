import unittest

from tools.package.source_hash_provenance_v242 import validate_v242


def record():
    common = {"source_id": "source-242", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-242", "package_version": "24.2.0", "source_attested_count": 1, "package_attested_count": 2}
    return {"schema_version": 242, "build_label": "source-provenance-v242", **common, "provenance_id": "provenance-242", "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True}, "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-242", **common, "proven": True}, "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None}}


class SourceHashProvenanceV242Test(unittest.TestCase):
    def test_accepts_attested_counts(self):
        self.assertEqual(validate_v242(record()), [])

    def test_requires_matching_attested_counts(self):
        item = record()
        item["source"]["source_attested_count"] = 0
        item["provenance"]["package_attested_count"] = 3
        errors = validate_v242(item)
        self.assertTrue(any("source.source_attested_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_attested_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 241
        item["provenance"]["proven"] = False
        errors = validate_v242(item)
        self.assertTrue(any("schema_version must be 242" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v242(item)))


if __name__ == "__main__":
    unittest.main()
