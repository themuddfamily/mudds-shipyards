import unittest

from tools.package.source_hash_provenance_v197 import validate_v197


def record():
    common = {"source_id": "source-197", "source_commit": "f" * 40, "source_hash": "a" * 64, "source_version": "src-197", "package_version": "19.7.0", "source_route_count": 3, "package_route_count": 4}
    return {
        "schema_version": 197, "build_label": "source-provenance-v197", **common, "provenance_id": "provenance-197",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-197", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV197Test(unittest.TestCase):
    def test_accepts_route_counts(self):
        self.assertEqual(validate_v197(record()), [])

    def test_requires_matching_route_counts(self):
        item = record()
        item["source"]["source_route_count"] = 2
        item["provenance"]["package_route_count"] = 5
        errors = validate_v197(item)
        self.assertTrue(any("source.source_route_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_route_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 196
        item["provenance"]["proven"] = False
        errors = validate_v197(item)
        self.assertTrue(any("schema_version must be 197" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v197(item)))


if __name__ == "__main__":
    unittest.main()
