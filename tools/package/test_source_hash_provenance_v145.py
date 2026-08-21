import unittest

from tools.package.source_hash_provenance_v145 import validate_v145


def record():
    common = {"source_id": "source-145", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-145", "package_version": "14.5.0", "source_review_status": "approved", "package_release_status": "candidate"}
    return {
        "schema_version": 145, "build_label": "source-provenance-v145", **common, "provenance_id": "provenance-145",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-145", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV145Test(unittest.TestCase):
    def test_accepts_review_release_status_binding(self):
        self.assertEqual(validate_v145(record()), [])

    def test_requires_review_release_status_binding(self):
        item = record()
        item["source"]["source_review_status"] = "pending"
        item["provenance"]["package_release_status"] = "released"
        errors = validate_v145(item)
        self.assertTrue(any("source.source_review_status must match" in error for error in errors))
        self.assertTrue(any("provenance.package_release_status must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 144
        item["provenance"]["proven"] = False
        errors = validate_v145(item)
        self.assertTrue(any("schema_version must be 145" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_hardware(self):
        item = record()
        item["native_execution"]["hardware"] = "x86_64"
        self.assertTrue(any("hardware must be null" in error for error in validate_v145(item)))


if __name__ == "__main__":
    unittest.main()
