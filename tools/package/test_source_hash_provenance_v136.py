import unittest

from tools.package.source_hash_provenance_v136 import validate_v136


def record():
    common = {"source_id": "source-136", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-136", "package_version": "13.6.0", "source_license": "MIT", "package_license": "MIT"}
    return {
        "schema_version": 136, "build_label": "source-provenance-v136", **common, "provenance_id": "provenance-136",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-136", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV136Test(unittest.TestCase):
    def test_accepts_license_binding(self):
        self.assertEqual(validate_v136(record()), [])

    def test_requires_license_binding(self):
        item = record()
        item["source"]["source_license"] = "Apache-2.0"
        item["provenance"]["package_license"] = "Apache-2.0"
        errors = validate_v136(item)
        self.assertTrue(any("source.source_license must match" in error for error in errors))
        self.assertTrue(any("provenance.package_license must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 135
        item["provenance"]["proven"] = False
        errors = validate_v136(item)
        self.assertTrue(any("schema_version must be 136" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v136(item)))


if __name__ == "__main__":
    unittest.main()
