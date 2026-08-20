import unittest

from tools.package.source_hash_authority_binding_reconciliation_v20 import validate_v20


def reconciliation():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 20,
        "build_label": "reconciliation-v20-42",
        "source_commit": commit,
        "authority_id": "authority-42",
        "authority_digest": digest,
        "reconciliation_id": "reconcile-42",
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "source_commit": commit, "digest": digest},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "authority_id": "authority-42", "reconciliation_id": "reconcile-42", "source_commit": commit, "digest": digest, "bindings_match": True},
        "review": {"status": "PASS", "evidence": "review ledger", "owner": "operator", "reviewed_at": "2026-08-20T12:00:00Z", "reconciliation_id": "reconcile-42"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuthorityBindingReconciliationV20Test(unittest.TestCase):
    def test_accepts_authority_reconciliation(self):
        self.assertEqual(validate_v20(reconciliation()), [])

    def test_requires_schema_v20_and_matching_digest(self):
        item = reconciliation()
        item["schema_version"] = 19
        item["reconciliation"]["digest"] = "c" * 64
        errors = validate_v20(item)
        self.assertTrue(any("schema_version must be 20" in error for error in errors))
        self.assertTrue(any("reconciliation.digest must match" in error for error in errors))

    def test_rejects_authority_or_reconciliation_id_drift(self):
        item = reconciliation()
        item["authority"]["source_commit"] = "d" * 40
        item["review"]["reconciliation_id"] = "other"
        errors = validate_v20(item)
        self.assertTrue(any("authority.source_commit must match" in error for error in errors))
        self.assertTrue(any("review.reconciliation_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = reconciliation()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v20(item)))


if __name__ == "__main__":
    unittest.main()
