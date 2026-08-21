import unittest

from tools.package.source_hash_provenance_v142 import validate_v142


def record():
    common = {"source_id": "source-142", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-142", "package_version": "14.2.0", "source_commit_date": "2026-08-20", "package_release_date": "2026-08-21"}
    return {
        "schema_version": 142, "build_label": "source-provenance-v142", **common, "provenance_id": "provenance-142",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-142", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV142Test(unittest.TestCase):
    def test_accepts_commit_release_dates(self):
        self.assertEqual(validate_v142(record()), [])

    def test_requires_commit_release_date_binding(self):
        item = record()
        item["source"]["source_commit_date"] = "2026-08-19"
        item["provenance"]["package_release_date"] = "2026-08-22"
        errors = validate_v142(item)
        self.assertTrue(any("source.source_commit_date must match" in error for error in errors))
        self.assertTrue(any("provenance.package_release_date must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 141
        item["provenance"]["proven"] = False
        errors = validate_v142(item)
        self.assertTrue(any("schema_version must be 142" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v142(item)))


if __name__ == "__main__":
    unittest.main()
