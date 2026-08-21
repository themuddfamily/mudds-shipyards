import unittest

from tools.package.source_hash_provenance_v196 import validate_v196


def record():
    common = {"source_id": "source-196", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-196", "package_version": "19.6.0", "source_endpoint_count": 2, "package_endpoint_count": 3}
    return {
        "schema_version": 196, "build_label": "source-provenance-v196", **common, "provenance_id": "provenance-196",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-196", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV196Test(unittest.TestCase):
    def test_accepts_endpoint_counts(self):
        self.assertEqual(validate_v196(record()), [])

    def test_requires_matching_endpoint_counts(self):
        item = record()
        item["source"]["source_endpoint_count"] = 1
        item["provenance"]["package_endpoint_count"] = 4
        errors = validate_v196(item)
        self.assertTrue(any("source.source_endpoint_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_endpoint_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 195
        item["provenance"]["proven"] = False
        errors = validate_v196(item)
        self.assertTrue(any("schema_version must be 196" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v196(item)))


if __name__ == "__main__":
    unittest.main()
