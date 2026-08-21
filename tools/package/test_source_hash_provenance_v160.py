import unittest

from tools.package.source_hash_provenance_v160 import validate_v160


def record():
    common = {"source_id": "source-160", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-160", "package_version": "16.0.0", "source_signature_count": 1, "package_signature_count": 2}
    return {
        "schema_version": 160, "build_label": "source-provenance-v160", **common, "provenance_id": "provenance-160",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-160", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV160Test(unittest.TestCase):
    def test_accepts_signature_counts(self):
        self.assertEqual(validate_v160(record()), [])

    def test_requires_matching_signature_counts(self):
        item = record()
        item["source"]["source_signature_count"] = 0
        item["provenance"]["package_signature_count"] = 3
        errors = validate_v160(item)
        self.assertTrue(any("source.source_signature_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_signature_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 159
        item["provenance"]["proven"] = False
        errors = validate_v160(item)
        self.assertTrue(any("schema_version must be 160" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v160(item)))


if __name__ == "__main__":
    unittest.main()
