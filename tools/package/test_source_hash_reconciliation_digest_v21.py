import unittest

from tools.package.source_hash_reconciliation_digest_v21 import validate_v21


def reconciliation():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 21,
        "build_label": "reconcile-digest-v21-42",
        "source_commit": commit,
        "reconciliation_id": "reconcile-42",
        "reconciliation_digest": digest,
        "source": {"status": "PASS", "evidence": "source record", "source_commit": commit, "manifest_digest": "c" * 64},
        "digest": {"status": "PASS", "evidence": "digest record", "value": digest, "reconciliation_id": "reconcile-42"},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "reconciliation_id": "reconcile-42", "digest": digest, "source_commit": commit, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashReconciliationDigestV21Test(unittest.TestCase):
    def test_accepts_reconciliation_digest(self):
        self.assertEqual(validate_v21(reconciliation()), [])

    def test_requires_schema_v21_and_matching_digest(self):
        item = reconciliation()
        item["schema_version"] = 20
        item["reconciliation"]["digest"] = "d" * 64
        errors = validate_v21(item)
        self.assertTrue(any("schema_version must be 21" in error for error in errors))
        self.assertTrue(any("reconciliation.digest must match" in error for error in errors))

    def test_rejects_source_or_reconciliation_id_drift(self):
        item = reconciliation()
        item["source"]["source_commit"] = "d" * 40
        item["digest"]["reconciliation_id"] = "other"
        errors = validate_v21(item)
        self.assertTrue(any("source.source_commit must match" in error for error in errors))
        self.assertTrue(any("digest.reconciliation_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = reconciliation()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v21(item)))


if __name__ == "__main__":
    unittest.main()
