import unittest

from tools.package.source_hash_provenance_reconciliation_v22 import validate_v22


def provenance():
    commit = "b" * 40
    digest = "a" * 64
    return {
        "schema_version": 22,
        "build_label": "provenance-reconcile-v22-42",
        "source_commit": commit,
        "provenance_id": "prov-42",
        "provenance_digest": digest,
        "reconciliation_id": "reconcile-42",
        "provenance": {"status": "PASS", "evidence": "provenance ledger", "provenance_id": "prov-42", "source_commit": commit, "digest": digest},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "provenance_id": "prov-42", "reconciliation_id": "reconcile-42", "source_commit": commit, "digest": digest, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashProvenanceReconciliationV22Test(unittest.TestCase):
    def test_accepts_provenance_reconciliation(self):
        self.assertEqual(validate_v22(provenance()), [])

    def test_requires_schema_v22_and_matching_provenance_digest(self):
        item = provenance()
        item["schema_version"] = 21
        item["provenance"]["digest"] = "c" * 64
        errors = validate_v22(item)
        self.assertTrue(any("schema_version must be 22" in error for error in errors))
        self.assertTrue(any("provenance.digest must match" in error for error in errors))

    def test_rejects_reconciliation_or_source_drift(self):
        item = provenance()
        item["reconciliation"]["reconciliation_id"] = "other"
        item["reconciliation"]["source_commit"] = "d" * 40
        errors = validate_v22(item)
        self.assertTrue(any("reconciliation_id must match" in error for error in errors))
        self.assertTrue(any("source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = provenance()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v22(item)))


if __name__ == "__main__":
    unittest.main()
