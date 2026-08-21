import unittest

from tools.package.source_hash_provenance_v152 import validate_v152


def record():
    common = {"source_id": "source-152", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-152", "package_version": "15.2.0", "source_evidence_count": 3, "package_evidence_count": 4}
    return {
        "schema_version": 152, "build_label": "source-provenance-v152", **common, "provenance_id": "provenance-152",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-152", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV152Test(unittest.TestCase):
    def test_accepts_evidence_counts(self):
        self.assertEqual(validate_v152(record()), [])

    def test_requires_matching_evidence_counts(self):
        item = record()
        item["source"]["source_evidence_count"] = 2
        item["provenance"]["package_evidence_count"] = 5
        errors = validate_v152(item)
        self.assertTrue(any("source.source_evidence_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_evidence_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 151
        item["provenance"]["proven"] = False
        errors = validate_v152(item)
        self.assertTrue(any("schema_version must be 152" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v152(item)))


if __name__ == "__main__":
    unittest.main()
