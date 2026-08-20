import unittest

from tools.package.source_hash_audit_summary_digest_validator import validate_digest


def digest():
    summary = "a" * 64
    manifest = "b" * 64
    return {
        "schema_version": 1,
        "build_label": "digest-summary-42",
        "source_commit": "c" * 40,
        "summary_digest": summary,
        "manifest_digest": manifest,
        "digest_check": {"status": "PASS", "evidence": "digest comparison", "summary_matches": True, "manifest_matches": True, "computed_summary_digest": summary, "computed_manifest_digest": manifest},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditSummaryDigestValidatorTest(unittest.TestCase):
    def test_accepts_matching_summary_digests(self):
        self.assertEqual(validate_digest(digest()), [])

    def test_rejects_invalid_digest_format(self):
        item = digest()
        item["summary_digest"] = "bad"
        self.assertTrue(any("summary_digest must be a 64-character" in error for error in validate_digest(item)))

    def test_rejects_computed_digest_drift(self):
        item = digest()
        item["digest_check"]["computed_manifest_digest"] = "d" * 64
        self.assertTrue(any("computed_manifest_digest must match" in error for error in validate_digest(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = digest()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_digest(item)))


if __name__ == "__main__":
    unittest.main()
