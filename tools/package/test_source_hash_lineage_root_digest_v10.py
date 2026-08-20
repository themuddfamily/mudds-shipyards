import unittest

from tools.package.source_hash_lineage_root_digest_v10 import validate_v10


def root():
    digest = "a" * 64
    return {
        "schema_version": 10,
        "build_label": "root-v10-42",
        "source_commit": "b" * 40,
        "root_digest": digest,
        "root_id": "root-42",
        "root": {"status": "PASS", "evidence": "root ledger", "root_id": "root-42", "source_commit": "b" * 40, "parent_lineage": "lineage-42"},
        "digest": {"status": "PASS", "evidence": "root digest", "value": digest, "root_id": "root-42", "reproducible": True},
        "review": {"status": "PASS", "evidence": "review ledger", "owner": "operator", "reviewed_at": "2026-08-20T12:00:00Z", "root_id": "root-42"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashLineageRootDigestV10Test(unittest.TestCase):
    def test_accepts_v10_root_summary(self):
        self.assertEqual(validate_v10(root()), [])

    def test_requires_schema_v10_and_parent_lineage(self):
        item = root()
        item["schema_version"] = 9
        item["root"]["parent_lineage"] = None
        errors = validate_v10(item)
        self.assertTrue(any("schema_version must be 10" in error for error in errors))
        self.assertTrue(any("parent_lineage is required" in error for error in errors))

    def test_rejects_digest_or_root_id_drift(self):
        item = root()
        item["digest"]["value"] = "c" * 64
        item["review"]["root_id"] = "other"
        errors = validate_v10(item)
        self.assertTrue(any("digest.value must match" in error for error in errors))
        self.assertTrue(any("review.root_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = root()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v10(item)))


if __name__ == "__main__":
    unittest.main()
