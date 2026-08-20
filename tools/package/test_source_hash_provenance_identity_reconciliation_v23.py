import unittest

from tools.package.source_hash_provenance_identity_reconciliation_v23 import validate_v23


def identity():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 23,
        "build_label": "identity-reconcile-v23-42",
        "source_commit": commit,
        "provenance_id": "prov-42",
        "identity_digest": digest,
        "reconciliation_id": "reconcile-42",
        "identity": {"status": "PASS", "evidence": "identity record", "provenance_id": "prov-42", "source_commit": commit, "digest": digest, "stable": True},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "provenance_id": "prov-42", "reconciliation_id": "reconcile-42", "digest": digest, "source_commit": commit, "identity_matches": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceIdentityReconciliationV23Test(unittest.TestCase):
    def test_accepts_provenance_identity_reconciliation(self):
        self.assertEqual(validate_v23(identity()), [])

    def test_requires_schema_v23_and_stable_identity(self):
        item = identity()
        item["schema_version"] = 22
        item["identity"]["stable"] = False
        errors = validate_v23(item)
        self.assertTrue(any("schema_version must be 23" in error for error in errors))
        self.assertTrue(any("stable must be true" in error for error in errors))

    def test_rejects_digest_or_reconciliation_id_drift(self):
        item = identity()
        item["reconciliation"]["digest"] = "c" * 64
        item["reconciliation"]["reconciliation_id"] = "other"
        errors = validate_v23(item)
        self.assertTrue(any("reconciliation.digest must match" in error for error in errors))
        self.assertTrue(any("reconciliation_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = identity()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v23(item)))


if __name__ == "__main__":
    unittest.main()
