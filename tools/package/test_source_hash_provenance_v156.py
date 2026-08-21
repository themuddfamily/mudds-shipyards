import unittest

from tools.package.source_hash_provenance_v156 import validate_v156


def record():
    common = {"source_id": "source-156", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-156", "package_version": "15.6.0", "source_dependency_count": 6, "package_dependency_count": 7}
    return {
        "schema_version": 156, "build_label": "source-provenance-v156", **common, "provenance_id": "provenance-156",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-156", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV156Test(unittest.TestCase):
    def test_accepts_dependency_counts(self):
        self.assertEqual(validate_v156(record()), [])

    def test_requires_matching_dependency_counts(self):
        item = record()
        item["source"]["source_dependency_count"] = 5
        item["provenance"]["package_dependency_count"] = 8
        errors = validate_v156(item)
        self.assertTrue(any("source.source_dependency_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_dependency_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 155
        item["provenance"]["proven"] = False
        errors = validate_v156(item)
        self.assertTrue(any("schema_version must be 156" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v156(item)))


if __name__ == "__main__":
    unittest.main()
