import unittest

from tools.package.artifact_completeness_rollup_validator import validate_completeness


def completeness():
    component = lambda evidence: {"status": "PASS", "evidence": evidence}
    return {
        "schema_version": 1,
        "build_label": "complete-42",
        "source_commit": "a" * 40,
        "artifact_label": "game.exe",
        "components": {"build": component("export"), "source": component("manifest"), "package": component("PCK"), "runtime": component("smoke"), "legal": component("ledger")},
        "accounted_files": 142,
        "unaccounted_files": 0,
        "complete": True,
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class ArtifactCompletenessRollupValidatorTest(unittest.TestCase):
    def test_accepts_complete_evidence_chain(self):
        self.assertEqual(validate_completeness(completeness()), [])

    def test_requires_all_component_categories(self):
        item = completeness()
        del item["components"]["legal"]
        self.assertTrue(any("components.legal is required" in error for error in validate_completeness(item)))

    def test_rejects_unaccounted_files_or_incomplete_flag(self):
        item = completeness()
        item["unaccounted_files"] = 1
        item["complete"] = False
        errors = validate_completeness(item)
        self.assertTrue(any("unaccounted_files must be 0" in error for error in errors))
        self.assertTrue(any("complete must be true" in error for error in errors))

    def test_native_not_run_cannot_carry_platform(self):
        item = completeness()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_completeness(item)))


if __name__ == "__main__":
    unittest.main()
