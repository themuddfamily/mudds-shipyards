import unittest

from tools.package.source_hash_summary_digest_audit_v2 import validate_v2


def audit():
    digest = "a" * 64
    return {
        "schema_version": 2,
        "build_label": "audit-v2-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "audit_id": "audit-42",
        "digest_audit": {"status": "PASS", "evidence": "v2 digest report", "source_bound": True, "digest_reproducible": True, "observed_digest": digest},
        "evidence_record": {"status": "PASS", "evidence": "ledger entry", "audit_id": "audit-42"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashSummaryDigestAuditV2Test(unittest.TestCase):
    def test_accepts_v2_audit(self):
        self.assertEqual(validate_v2(audit()), [])

    def test_requires_schema_v2(self):
        item = audit()
        item["schema_version"] = 1
        self.assertTrue(any("schema_version must be 2" in error for error in validate_v2(item)))

    def test_rejects_digest_or_audit_id_drift(self):
        item = audit()
        item["digest_audit"]["observed_digest"] = "c" * 64
        item["evidence_record"]["audit_id"] = "other"
        errors = validate_v2(item)
        self.assertTrue(any("observed_digest must match" in error for error in errors))
        self.assertTrue(any("audit_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v2(item)))


if __name__ == "__main__":
    unittest.main()
