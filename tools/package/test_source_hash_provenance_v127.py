import unittest

from tools.package.source_hash_provenance_v127 import validate_v127


def record():
    common = {"source_id": "source-127", "source_commit": "1" * 40, "source_hash": "e" * 64, "source_version": "src-127", "package_version": "12.7.0", "reviewer": "release-auditor", "reviewed_at": "2026-08-21T12:00:00Z"}
    return {
        "schema_version": 127, "build_label": "source-provenance-v127", **common, "provenance_id": "provenance-127",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-127", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV127Test(unittest.TestCase):
    def test_accepts_reviewed_binding(self):
        self.assertEqual(validate_v127(record()), [])

    def test_requires_review_metadata_binding(self):
        item = record()
        item["source"]["reviewer"] = "other"
        item["provenance"]["reviewed_at"] = "not-a-time"
        errors = validate_v127(item)
        self.assertTrue(any("source.reviewer must match" in error for error in errors))
        self.assertTrue(any("provenance.reviewed_at must match" in error for error in errors))

    def test_rejects_invalid_timestamp_or_provenance_flag(self):
        item = record()
        item["reviewed_at"] = "yesterday"
        item["provenance"]["proven"] = False
        errors = validate_v127(item)
        self.assertTrue(any("ISO-8601" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = record()
        item["native_execution"]["platform"] = "Linux"
        self.assertTrue(any("platform must be null" in error for error in validate_v127(item)))


if __name__ == "__main__":
    unittest.main()
