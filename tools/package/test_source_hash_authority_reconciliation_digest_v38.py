import unittest

from tools.package.source_hash_authority_reconciliation_digest_v38 import validate_v38


def authority():
    commit = "a" * 40
    authority_digest = "b" * 64
    reconciliation_digest = "c" * 64
    return {
        "schema_version": 38,
        "build_label": "authority-reconcile-v38-42",
        "source_commit": commit,
        "authority_id": "authority-42",
        "authority_digest": authority_digest,
        "reconciliation_id": "reconcile-42",
        "reconciliation_digest": reconciliation_digest,
        "authority": {"status": "PASS", "evidence": "authority record", "authority_id": "authority-42", "source_commit": commit, "digest": authority_digest},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "reconciliation_id": "reconcile-42", "authority_id": "authority-42", "digest": reconciliation_digest, "authority_digest": authority_digest, "source_commit": commit, "reconciled": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuthorityReconciliationDigestV38Test(unittest.TestCase):
    def test_accepts_authority_reconciliation_digest(self):
        self.assertEqual(validate_v38(authority()), [])

    def test_requires_schema_v38_and_matching_reconciliation_digest(self):
        item = authority()
        item["schema_version"] = 37
        item["reconciliation"]["digest"] = "d" * 64
        errors = validate_v38(item)
        self.assertTrue(any("schema_version must be 38" in error for error in errors))
        self.assertTrue(any("reconciliation.digest must match" in error for error in errors))

    def test_rejects_authority_or_source_drift(self):
        item = authority()
        item["authority"]["authority_id"] = "other"
        item["reconciliation"]["source_commit"] = "d" * 40
        errors = validate_v38(item)
        self.assertTrue(any("authority.authority_id must match" in error for error in errors))
        self.assertTrue(any("reconciliation.source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = authority()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v38(item)))


if __name__ == "__main__":
    unittest.main()
