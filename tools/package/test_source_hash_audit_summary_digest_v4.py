import unittest

from tools.package.source_hash_audit_summary_digest_v4 import validate_v4


def audit():
    digest = "a" * 64
    return {
        "schema_version": 4,
        "build_label": "audit-v4-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "audit_id": "audit-42",
        "reviewed_at": "2026-08-20",
        "digest_audit": {"status": "PASS", "evidence": "v4 report", "source_bound": True, "digest_reproducible": True, "reviewed": True, "scope_complete": True, "observed_digest": digest},
        "review": {"status": "PASS", "evidence": "review ledger", "audit_id": "audit-42", "reviewer": "operator", "reviewer_role": "release reviewer"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditSummaryDigestV4Test(unittest.TestCase):
    def test_accepts_v4_audit(self):
        self.assertEqual(validate_v4(audit()), [])

    def test_requires_schema_v4_and_scope_complete(self):
        item = audit()
        item["schema_version"] = 3
        item["digest_audit"]["scope_complete"] = False
        errors = validate_v4(item)
        self.assertTrue(any("schema_version must be 4" in error for error in errors))
        self.assertTrue(any("scope_complete must be true" in error for error in errors))

    def test_passed_review_requires_role(self):
        item = audit()
        item["review"]["reviewer_role"] = None
        self.assertTrue(any("reviewer_role is required" in error for error in validate_v4(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v4(item)))


if __name__ == "__main__":
    unittest.main()
