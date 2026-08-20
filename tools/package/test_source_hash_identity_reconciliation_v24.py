import unittest

from tools.package.source_hash_identity_reconciliation_v24 import validate_v24


def identity():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 24,
        "build_label": "identity-v24-42",
        "source_commit": commit,
        "identity_id": "identity-42",
        "identity_digest": digest,
        "reconciliation_id": "reconcile-42",
        "identity": {"status": "PASS", "evidence": "identity record", "identity_id": "identity-42", "source_commit": commit, "digest": digest},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "identity_id": "identity-42", "reconciliation_id": "reconcile-42", "digest": digest, "source_commit": commit, "match": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashIdentityReconciliationV24Test(unittest.TestCase):
    def test_accepts_identity_reconciliation(self):
        self.assertEqual(validate_v24(identity()), [])

    def test_requires_schema_v24_and_matching_identity_digest(self):
        item = identity()
        item["schema_version"] = 23
        item["reconciliation"]["digest"] = "c" * 64
        errors = validate_v24(item)
        self.assertTrue(any("schema_version must be 24" in error for error in errors))
        self.assertTrue(any("reconciliation.digest must match" in error for error in errors))

    def test_rejects_identity_or_source_drift(self):
        item = identity()
        item["identity"]["identity_id"] = "other"
        item["reconciliation"]["source_commit"] = "d" * 40
        errors = validate_v24(item)
        self.assertTrue(any("identity.identity_id must match" in error for error in errors))
        self.assertTrue(any("reconciliation.source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = identity()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v24(item)))


if __name__ == "__main__":
    unittest.main()
