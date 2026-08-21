import unittest

from tools.package.source_hash_provenance_v199 import validate_v199


def record():
    common = {"source_id": "source-199", "source_commit": "b" * 40, "source_hash": "c" * 64, "source_version": "src-199", "package_version": "19.9.0", "source_callback_count": 2, "package_callback_count": 3}
    return {
        "schema_version": 199, "build_label": "source-provenance-v199", **common, "provenance_id": "provenance-199",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-199", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV199Test(unittest.TestCase):
    def test_accepts_callback_counts(self):
        self.assertEqual(validate_v199(record()), [])

    def test_requires_matching_callback_counts(self):
        item = record()
        item["source"]["source_callback_count"] = 1
        item["provenance"]["package_callback_count"] = 4
        errors = validate_v199(item)
        self.assertTrue(any("source.source_callback_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_callback_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 198
        item["provenance"]["proven"] = False
        errors = validate_v199(item)
        self.assertTrue(any("schema_version must be 199" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v199(item)))


if __name__ == "__main__":
    unittest.main()
