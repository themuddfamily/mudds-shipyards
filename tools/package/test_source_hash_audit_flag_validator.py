import unittest

from tools.package.source_hash_audit_flag_validator import validate_flags


def flags():
    return {
        "schema_version": 1,
        "build_label": "flags-42",
        "source_commit": "a" * 40,
        "source_audit": {"status": "PASS", "evidence": "source report"},
        "artifact_audit": {"status": "PASS", "evidence": "hash report"},
        "binding_audit": {"status": "PASS", "evidence": "binding report"},
        "overall_pass": True,
        "native_execution": {"status": "NOT_RUN", "evidence": None, "reason": "native host unavailable", "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceHashAuditFlagValidatorTest(unittest.TestCase):
    def test_accepts_explicit_passing_audit_flags(self):
        self.assertEqual(validate_flags(flags()), [])

    def test_overall_pass_requires_all_components(self):
        item = flags()
        item["artifact_audit"]["status"] = "UNKNOWN"
        item["artifact_audit"]["reason"] = "hash record missing"
        self.assertTrue(any("overall_pass requires" in error for error in validate_flags(item)))

    def test_nonpassing_component_requires_reason(self):
        item = flags()
        item["source_audit"]["status"] = "FAIL"
        self.assertTrue(any("reason is required" in error for error in validate_flags(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = flags()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_flags(item)))


if __name__ == "__main__":
    unittest.main()
