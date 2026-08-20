import unittest

from tools.package.source_hash_digest_reconciliation_v26 import validate_v26


def digest():
    commit = "b" * 40
    value = "a" * 64
    return {
        "schema_version": 26,
        "build_label": "digest-reconcile-v26-42",
        "source_commit": commit,
        "digest_id": "digest-42",
        "digest_value": value,
        "reconciliation_id": "reconcile-42",
        "digest": {"status": "PASS", "evidence": "digest record", "digest_id": "digest-42", "value": value, "source_commit": commit},
        "reconciliation": {"status": "PASS", "evidence": "reconciliation report", "digest_id": "digest-42", "reconciliation_id": "reconcile-42", "value": value, "consistent": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashDigestReconciliationV26Test(unittest.TestCase):
    def test_accepts_digest_reconciliation(self):
        self.assertEqual(validate_v26(digest()), [])

    def test_requires_schema_v26_and_matching_value(self):
        item = digest()
        item["schema_version"] = 25
        item["reconciliation"]["value"] = "c" * 64
        errors = validate_v26(item)
        self.assertTrue(any("schema_version must be 26" in error for error in errors))
        self.assertTrue(any("reconciliation.value must match" in error for error in errors))

    def test_rejects_digest_id_or_source_drift(self):
        item = digest()
        item["digest"]["digest_id"] = "other"
        item["digest"]["source_commit"] = "d" * 40
        errors = validate_v26(item)
        self.assertTrue(any("digest_id must match" in error for error in errors))
        self.assertTrue(any("source_commit must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = digest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v26(item)))


if __name__ == "__main__":
    unittest.main()
