import unittest

from tools.package.source_hash_provenance_v158 import validate_v158


def record():
    common = {"source_id": "source-158", "source_commit": "e" * 40, "source_hash": "f" * 64, "source_version": "src-158", "package_version": "15.8.0", "source_reviewer_count": 2, "package_reviewer_count": 3}
    return {
        "schema_version": 158, "build_label": "source-provenance-v158", **common, "provenance_id": "provenance-158",
        "source": {"status": "PASS", "evidence": "source-record", **common, "identified": True},
        "provenance": {"status": "PASS", "evidence": "provenance-record", "provenance_id": "provenance-158", **common, "proven": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceV158Test(unittest.TestCase):
    def test_accepts_reviewer_counts(self):
        self.assertEqual(validate_v158(record()), [])

    def test_requires_matching_reviewer_counts(self):
        item = record()
        item["source"]["source_reviewer_count"] = 1
        item["provenance"]["package_reviewer_count"] = 4
        errors = validate_v158(item)
        self.assertTrue(any("source.source_reviewer_count must match" in error for error in errors))
        self.assertTrue(any("provenance.package_reviewer_count must match" in error for error in errors))

    def test_rejects_schema_or_provenance_flag(self):
        item = record()
        item["schema_version"] = 157
        item["provenance"]["proven"] = False
        errors = validate_v158(item)
        self.assertTrue(any("schema_version must be 158" in error for error in errors))
        self.assertTrue(any("proven must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_evidence_path(self):
        item = record()
        item["native_execution"]["evidence_path"] = "native.log"
        self.assertTrue(any("evidence_path must be null" in error for error in validate_v158(item)))


if __name__ == "__main__":
    unittest.main()
