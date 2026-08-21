import unittest

from tools.package.source_hash_provenance_v185 import validate_v185


def record():
    common = {"source_id": "source-185", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-185", "package_version": "18.5.0", "source_evidence_type_count": 2, "package_evidence_type_count": 3}
    return {
        "schema_version": 185, "build_label": "source-provenance-v185", **common, "provenance_id": "provenance-185",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-185", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV185Test(unittest.TestCase):
    def test_accepts_evidence_type_counts(self):
        self.assertEqual(validate_v185(record()), [])

    def test_requires_matching_evidence_type_counts(self):
        item = record()
        item["source"]["source_evidence_type_count"] = 1
        item["provenance"]["package_evidence_type_count"] = 4
        errors = validate_v185(item)
        self.assertTrue(any("source.source_evidence_type_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_evidence_type_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 184
        item["provenance"]["proven"] = False
        errors = validate_v185(item)
        self.assertTrue(any("schema_version must be 185" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v185(item)))


if __name__ == "__main__":
    unittest.main()
