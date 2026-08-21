import unittest

from tools.package.source_hash_provenance_v134 import validate_v134


def record():
    common = {"source_id": "source-134", "source_commit": "8" * 40, "source_hash": "f" * 64, "source_version": "src-134", "package_version": "13.4.0", "source_ref": "refs/tags/v13.4.0", "package_release": "release-134"}
    return {
        "schema_version": 134, "build_label": "source-provenance-v134", **common, "provenance_id": "provenance-134",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-134", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV134Test(unittest.TestCase):
    def test_accepts_ref_release_binding(self):
        self.assertEqual(validate_v134(record()), [])

    def test_requires_ref_and_release_binding(self):
        item = record()
        item["source"]["source_ref"] = "refs/heads/main"
        item["provenance"]["package_release"] = "release-other"
        errors = validate_v134(item)
        self.assertTrue(any("source.source_ref must match" in error for error in errors))
        self.assertTrue(any("provenance.package_release must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 133
        item["provenance"]["proven"] = False
        errors = validate_v134(item)
        self.assertTrue(any("schema_version must be 134" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v134(item)))


if __name__ == "__main__":
    unittest.main()
