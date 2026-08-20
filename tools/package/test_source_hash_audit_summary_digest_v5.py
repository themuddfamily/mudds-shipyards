import unittest

from tools.package.source_hash_audit_summary_digest_v5 import validate_v5


def audit():
    digest = "a" * 64
    return {
        "schema_version": 5,
        "build_label": "audit-v5-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "audit_id": "audit-42",
        "source_binding": {"status": "PASS", "evidence": "determinism record", "commit": "b" * 40, "deterministic": True},
        "digest_audit": {"status": "PASS", "evidence": "digest report", "observed_digest": digest, "reproducible": True},
        "review": {"status": "PASS", "evidence": "review ledger", "audit_id": "audit-42", "owner": "operator", "owner_role": "release reviewer", "reviewed_at": "2026-08-20T12:00:00Z"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditSummaryDigestV5Test(unittest.TestCase):
    def test_accepts_v5_audit(self):
        self.assertEqual(validate_v5(audit()), [])

    def test_requires_schema_v5_and_deterministic_binding(self):
        item = audit()
        item["schema_version"] = 4
        item["source_binding"]["deterministic"] = False
        errors = validate_v5(item)
        self.assertTrue(any("schema_version must be 5" in error for error in errors))
        self.assertTrue(any("deterministic must be true" in error for error in errors))

    def test_review_requires_owner_timestamp_and_matching_audit_id(self):
        item = audit()
        item["review"]["owner"] = None
        item["review"]["reviewed_at"] = None
        item["review"]["audit_id"] = "other"
        errors = validate_v5(item)
        self.assertTrue(any("owner is required" in error for error in errors))
        self.assertTrue(any("reviewed_at is required" in error for error in errors))
        self.assertTrue(any("audit_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v5(item)))


if __name__ == "__main__":
    unittest.main()
