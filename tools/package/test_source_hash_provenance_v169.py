import unittest

from tools.package.source_hash_provenance_v169 import validate_v169


def record():
    common = {"source_id": "source-169", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-169", "package_version": "16.9.0", "source_release_count": 2, "package_release_count": 3}
    return {
        "schema_version": 169, "build_label": "source-provenance-v169", **common, "provenance_id": "provenance-169",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-169", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV169Test(unittest.TestCase):
    def test_accepts_release_counts(self):
        self.assertEqual(validate_v169(record()), [])

    def test_requires_matching_release_counts(self):
        item = record()
        item["source"]["source_release_count"] = 1
        item["provenance"]["package_release_count"] = 4
        errors = validate_v169(item)
        self.assertTrue(any("source.source_release_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_release_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 168
        item["provenance"]["proven"] = False
        errors = validate_v169(item)
        self.assertTrue(any("schema_version must be 169" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v169(item)))


if __name__ == "__main__":
    unittest.main()
