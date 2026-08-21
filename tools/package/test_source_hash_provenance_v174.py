import unittest

from tools.package.source_hash_provenance_v174 import validate_v174


def record():
    common = {"source_id": "source-174", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-174", "package_version": "17.4.0", "source_byte_count": 1024, "package_byte_count": 2048}
    return {
        "schema_version": 174, "build_label": "source-provenance-v174", **common, "provenance_id": "provenance-174",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-174", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV174Test(unittest.TestCase):
    def test_accepts_byte_counts(self):
        self.assertEqual(validate_v174(record()), [])

    def test_requires_matching_byte_counts(self):
        item = record()
        item["source"]["source_byte_count"] = 1023
        item["provenance"]["package_byte_count"] = 2049
        errors = validate_v174(item)
        self.assertTrue(any("source.source_byte_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_byte_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 173
        item["provenance"]["proven"] = False
        errors = validate_v174(item)
        self.assertTrue(any("schema_version must be 174" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v174(item)))


if __name__ == "__main__":
    unittest.main()
