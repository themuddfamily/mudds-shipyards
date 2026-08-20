import unittest

from tools.package.source_hash_audit_provenance_summary_v8 import validate_v8


def summary():
    digest = "a" * 64
    return {
        "schema_version": 8,
        "build_label": "provenance-v8-42",
        "source_commit": "b" * 40,
        "summary_digest": digest,
        "provenance_id": "prov-42",
        "provenance": {"status": "PASS", "evidence": "provenance ledger", "provenance_id": "prov-42", "source_commit": "b" * 40, "origin": "source manifest"},
        "digest": {"status": "PASS", "evidence": "digest report", "observed": digest, "reproducible": True},
        "review": {"status": "PASS", "evidence": "review ledger", "owner": "operator", "reviewed_at": "2026-08-20T12:00:00Z", "provenance_id": "prov-42"},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditProvenanceSummaryV8Test(unittest.TestCase):
    def test_accepts_v8_provenance_summary(self):
        self.assertEqual(validate_v8(summary()), [])

    def test_requires_schema_v8_and_provenance_origin(self):
        item = summary()
        item["schema_version"] = 7
        item["provenance"]["origin"] = None
        errors = validate_v8(item)
        self.assertTrue(any("schema_version must be 8" in error for error in errors))
        self.assertTrue(any("origin is required" in error for error in errors))

    def test_rejects_digest_or_provenance_id_drift(self):
        item = summary()
        item["digest"]["observed"] = "c" * 64
        item["review"]["provenance_id"] = "other"
        errors = validate_v8(item)
        self.assertTrue(any("observed must match" in error for error in errors))
        self.assertTrue(any("review.provenance_id must match" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = summary()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_v8(item)))


if __name__ == "__main__":
    unittest.main()
