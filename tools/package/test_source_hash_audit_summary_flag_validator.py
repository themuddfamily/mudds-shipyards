import unittest

from tools.package.source_hash_audit_summary_flag_validator import validate_summary


def summary():
    return {
        "schema_version": 1,
        "build_label": "summary-flags-42",
        "source_commit": "a" * 40,
        "summary_label": "source-hash checks",
        "checks": [{"name": "source", "status": "PASS", "evidence": "source report"}, {"name": "hash", "status": "PASS", "evidence": "hash report"}],
        "total_checks": 2,
        "passed_checks": 2,
        "complete": True,
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditSummaryFlagValidatorTest(unittest.TestCase):
    def test_accepts_complete_summary_flags(self):
        self.assertEqual(validate_summary(summary()), [])

    def test_rejects_check_count_drift(self):
        item = summary()
        item["passed_checks"] = 1
        self.assertTrue(any("passed_checks must equal" in error for error in validate_summary(item)))

    def test_nonpassing_check_requires_reason(self):
        item = summary()
        item["checks"][0]["status"] = "FAIL"
        self.assertTrue(any("reason is required" in error for error in validate_summary(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = summary()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_summary(item)))


if __name__ == "__main__":
    unittest.main()
