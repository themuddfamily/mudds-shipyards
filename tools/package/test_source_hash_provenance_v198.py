import unittest

from tools.package.source_hash_provenance_v198 import validate_v198


def record():
    common = {"source_id": "source-198", "source_commit": "a" * 40, "source_hash": "b" * 64, "source_version": "src-198", "package_version": "19.8.0", "source_handler_count": 4, "package_handler_count": 5}
    return {
        "schema_version": 198, "build_label": "source-provenance-v198", **common, "provenance_id": "provenance-198",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-198", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV198Test(unittest.TestCase):
    def test_accepts_handler_counts(self):
        self.assertEqual(validate_v198(record()), [])

    def test_requires_matching_handler_counts(self):
        item = record()
        item["source"]["source_handler_count"] = 3
        item["provenance"]["package_handler_count"] = 6
        errors = validate_v198(item)
        self.assertTrue(any("source.source_handler_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_handler_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 197
        item["provenance"]["proven"] = False
        errors = validate_v198(item)
        self.assertTrue(any("schema_version must be 198" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v198(item)))


if __name__ == "__main__":
    unittest.main()
