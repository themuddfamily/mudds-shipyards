import unittest

from tools.package.source_hash_provenance_v200 import validate_v200


def record():
    common = {"source_id": "source-200", "source_commit": "c" * 40, "source_hash": "d" * 64, "source_version": "src-200", "package_version": "20.0.0", "source_event_count": 4, "package_event_count": 5}
    return {
        "schema_version": 200, "build_label": "source-provenance-v200", **common, "provenance_id": "provenance-200",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-200", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV200Test(unittest.TestCase):
    def test_accepts_event_counts(self):
        self.assertEqual(validate_v200(record()), [])

    def test_requires_matching_event_counts(self):
        item = record()
        item["source"]["source_event_count"] = 3
        item["provenance"]["package_event_count"] = 6
        errors = validate_v200(item)
        self.assertTrue(any("source.source_event_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_event_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 199
        item["provenance"]["proven"] = False
        errors = validate_v200(item)
        self.assertTrue(any("schema_version must be 200" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v200(item)))


if __name__ == "__main__":
    unittest.main()
