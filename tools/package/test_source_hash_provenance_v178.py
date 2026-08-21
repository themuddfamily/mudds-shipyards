import unittest

from tools.package.source_hash_provenance_v178 import validate_v178


def record():
    common = {"source_id": "source-178", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-178", "package_version": "17.8.0", "source_record_count": 4, "package_record_count": 5}
    return {
        "schema_version": 178, "build_label": "source-provenance-v178", **common, "provenance_id": "provenance-178",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-178", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV178Test(unittest.TestCase):
    def test_accepts_record_counts(self):
        self.assertEqual(validate_v178(record()), [])

    def test_requires_matching_record_counts(self):
        item = record()
        item["source"]["source_record_count"] = 3
        item["provenance"]["package_record_count"] = 6
        errors = validate_v178(item)
        self.assertTrue(any("source.source_record_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_record_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 177
        item["provenance"]["proven"] = False
        errors = validate_v178(item)
        self.assertTrue(any("schema_version must be 178" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v178(item)))


if __name__ == "__main__":
    unittest.main()
