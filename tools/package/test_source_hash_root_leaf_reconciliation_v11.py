import unittest

from tools.package.source_hash_root_leaf_reconciliation_v11 import validate_v11


def reconciliation():
    commit = "b" * 40
    return {
        "schema_version": 11,
        "build_label": "reconcile-v11-42",
        "source_commit": commit,
        "root_digest": "a" * 64,
        "reconciliation_id": "reconcile-42",
        "root": {"status": "PASS", "evidence": "root record", "digest": "a" * 64, "source_commit": commit},
        "leaves": [{"leaf_id": "leaf-1", "source_commit": commit, "digest": "c" * 64}],
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "reconciliation_id": "reconcile-42", "leaf_count": 1, "root_matches_leaves": True},
        "review": {"status": "PASS", "evidence": "review ledger", "owner": "operator", "reviewed_at": "2026-08-20T12:00:00Z", "reconciliation_id": "reconcile-42"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashRootLeafReconciliationV11Test(unittest.TestCase):
    def test_accepts_root_leaf_reconciliation(self):
        self.assertEqual(validate_v11(reconciliation()), [])

    def test_requires_schema_v11_and_matching_leaf_count(self):
        item = reconciliation()
        item["schema_version"] = 10
        item["reconciliation"]["leaf_count"] = 2
        errors = validate_v11(item)
        self.assertTrue(any("schema_version must be 11" in error for error in errors))
        self.assertTrue(any("leaf_count must equal" in error for error in errors))

    def test_rejects_duplicate_leaf_or_source_drift(self):
        item = reconciliation()
        item["leaves"].append(dict(item["leaves"][0]))
        item["leaves"][1]["source_commit"] = "d" * 40
        errors = validate_v11(item)
        self.assertTrue(any("leaf_id must be unique" in error for error in errors))
        self.assertTrue(any("source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = reconciliation()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v11(item)))


if __name__ == "__main__":
    unittest.main()
