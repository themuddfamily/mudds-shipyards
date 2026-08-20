import unittest

from tools.package.source_hash_audit_summary_digest_v3 import validate_v3


def audit():
    digest = "a" * 64
    return {
        "schema_version": 3,
        "build_label": "audit-v3-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "audit_id": "audit-42",
        "reviewed_at": "2026-08-20",
        "digest_audit": {"status": "PASS", "evidence": "v3 report", "source_bound": True, "digest_reproducible": True, "reviewed": True, "observed_digest": digest},
        "review": {"status": "PASS", "evidence": "review ledger", "audit_id": "audit-42", "reviewer": "operator"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditSummaryDigestV3Test(unittest.TestCase):
    def test_accepts_v3_audit(self):
        self.assertEqual(validate_v3(audit()), [])

    def test_requires_schema_v3_and_review_timestamp(self):
        item = audit()
        item["schema_version"] = 2
        item["reviewed_at"] = None
        errors = validate_v3(item)
        self.assertTrue(any("schema_version must be 3" in error for error in errors))
        self.assertTrue(any("reviewed_at is required" in error for error in errors))

    def test_passed_review_requires_reviewer_and_matching_id(self):
        item = audit()
        item["review"]["reviewer"] = None
        item["review"]["audit_id"] = "other"
        errors = validate_v3(item)
        self.assertTrue(any("reviewer is required" in error for error in errors))
        self.assertTrue(any("audit_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v3(item)))


if __name__ == "__main__":
    unittest.main()
