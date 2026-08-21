import unittest

from tools.package.source_hash_provenance_v163 import validate_v163


def record():
    common = {"source_id": "source-163", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-163", "package_version": "16.3.0", "source_value_count": 13, "package_value_count": 14}
    return {
        "schema_version": 163, "build_label": "source-provenance-v163", **common, "provenance_id": "provenance-163",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-163", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV163Test(unittest.TestCase):
    def test_accepts_value_counts(self):
        self.assertEqual(validate_v163(record()), [])

    def test_requires_matching_value_counts(self):
        item = record()
        item["source"]["source_value_count"] = 12
        item["provenance"]["package_value_count"] = 15
        errors = validate_v163(item)
        self.assertTrue(any("source.source_value_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_value_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 162
        item["provenance"]["proven"] = False
        errors = validate_v163(item)
        self.assertTrue(any("schema_version must be 163" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "arm64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v163(item)))


if __name__ == "__main__":
    unittest.main()
