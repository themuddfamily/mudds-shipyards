import unittest

from tools.package.source_hash_identity_digest_reconciliation_v25 import validate_v25


def identity():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 25,
        "build_label": "identity-digest-v25-42",
        "source_commit": commit,
        "identity_id": "identity-42",
        "identity_digest": digest,
        "reconciliation_id": "reconcile-42",
        "identity": {"status": "PASS", "evidence": "identity record", "identity_id": "identity-42", "source_commit": commit, "digest": digest},
        "digest": {"status": "PASS", "evidence": "digest record", "identity_id": "identity-42", "value": digest, "stable": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "reconciliation_id": "reconcile-42", "identity_id": "identity-42", "digest": digest, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashIdentityDigestReconciliationV25Test(unittest.TestCase):
    def test_accepts_identity_digest_reconciliation(self):
        self.assertEqual(validate_v25(identity()), [])

    def test_requires_schema_v25_and_stable_digest(self):
        item = identity()
        item["schema_version"] = 24
        item["digest"]["stable"] = False
        errors = validate_v25(item)
        self.assertTrue(any("schema_version must be 25" in error for error in errors))
        self.assertTrue(any("stable must be true" in error for error in errors))

    def test_rejects_identity_or_reconciliation_digest_drift(self):
        item = identity()
        item["identity"]["digest"] = "c" * 64
        item["reconciliation"]["reconciliation_id"] = "other"
        errors = validate_v25(item)
        self.assertTrue(any("identity.digest must match" in error for error in errors))
        self.assertTrue(any("reconciliation_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = identity()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v25(item)))


if __name__ == "__main__":
    unittest.main()
