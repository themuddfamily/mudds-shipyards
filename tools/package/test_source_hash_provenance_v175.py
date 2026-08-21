import unittest

from tools.package.source_hash_provenance_v175 import validate_v175


def record():
    common = {"source_id": "source-175", "source_commit": "d" * 40, "source_hash": "e" * 64, "source_version": "src-175", "package_version": "17.5.0", "source_hash_count": 3, "package_hash_count": 4}
    return {
        "schema_version": 175, "build_label": "source-provenance-v175", **common, "provenance_id": "provenance-175",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-175", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV175Test(unittest.TestCase):
    def test_accepts_hash_counts(self):
        self.assertEqual(validate_v175(record()), [])

    def test_requires_matching_hash_counts(self):
        item = record()
        item["source"]["source_hash_count"] = 2
        item["provenance"]["package_hash_count"] = 5
        errors = validate_v175(item)
        self.assertTrue(any("source.source_hash_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_hash_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 174
        item["provenance"]["proven"] = False
        errors = validate_v175(item)
        self.assertTrue(any("schema_version must be 175" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v175(item)))


if __name__ == "__main__":
    unittest.main()
