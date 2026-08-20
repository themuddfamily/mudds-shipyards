import unittest

from tools.package.source_hash_provenance_lineage_v9 import validate_v9


def lineage():
    digest = "a" * 64
    return {
        "schema_version": 9,
        "build_label": "lineage-v9-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "lineage_id": "lineage-42",
        "lineage": {"status": "PASS", "evidence": "lineage ledger", "lineage_id": "lineage-42", "source_commit": "b" * 40, "parent": "source-manifest"},
        "digest": {"status": "PASS", "evidence": "digest record", "value": digest, "lineage_id": "lineage-42"},
        "review": {"status": "PASS", "evidence": "review ledger", "owner": "operator", "reviewed_at": "2026-08-20T12:00:00Z", "lineage_id": "lineage-42"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceLineageV9Test(unittest.TestCase):
    def test_accepts_v9_lineage_summary(self):
        self.assertEqual(validate_v9(lineage()), [])

    def test_requires_schema_v9_and_lineage_parent(self):
        item = lineage()
        item["schema_version"] = 8
        item["lineage"]["parent"] = None
        errors = validate_v9(item)
        self.assertTrue(any("schema_version must be 9" in error for error in errors))
        self.assertTrue(any("parent is required" in error for error in errors))

    def test_rejects_digest_or_lineage_id_drift(self):
        item = lineage()
        item["digest"]["value"] = "c" * 64
        item["review"]["lineage_id"] = "other"
        errors = validate_v9(item)
        self.assertTrue(any("digest.value must match" in error for error in errors))
        self.assertTrue(any("review.lineage_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = lineage()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v9(item)))


if __name__ == "__main__":
    unittest.main()
