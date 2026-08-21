import unittest

from tools.package.source_hash_provenance_v170 import validate_v170


def record():
    common = {"source_id": "source-170", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-170", "package_version": "17.0.0", "source_version_count": 2, "package_version_count": 3}
    return {
        "schema_version": 170, "build_label": "source-provenance-v170", **common, "provenance_id": "provenance-170",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-170", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV170Test(unittest.TestCase):
    def test_accepts_version_counts(self):
        self.assertEqual(validate_v170(record()), [])

    def test_requires_matching_version_counts(self):
        item = record()
        item["source"]["source_version_count"] = 1
        item["provenance"]["package_version_count"] = 4
        errors = validate_v170(item)
        self.assertTrue(any("source.source_version_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_version_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 169
        item["provenance"]["proven"] = False
        errors = validate_v170(item)
        self.assertTrue(any("schema_version must be 170" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v170(item)))


if __name__ == "__main__":
    unittest.main()
