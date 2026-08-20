import unittest

from tools.package.research.source_current_release_audit import validate_audit


def audit():
    commit = "a" * 40
    return {
        "schema_version": 1,
        "release_label": "source-current-42",
        "source_commit": commit,
        "artifact_label": "build-42",
        "source_snapshot": {"status": "PASS", "evidence": "git status record", "commit": commit, "working_tree_clean": True},
        "package_snapshot": {"status": "PASS", "evidence": "build manifest", "artifact_label": "build-42", "built_from_commit": commit},
        "stale_evidence": {"status": "PASS", "evidence": "release ledger", "stale_artifacts": 0, "historical_records_excluded": True},
        "native_execution": {"status": "NOT_RUN", "evidence": None, "platform": None, "hardware": None, "evidence_path": None},
    }


class SourceCurrentReleaseAuditTest(unittest.TestCase):
    def test_accepts_source_current_record_with_native_not_run(self):
        self.assertEqual(validate_audit(audit()), [])

    def test_source_and_package_commits_must_match(self):
        item = audit()
        item["package_snapshot"]["built_from_commit"] = "b" * 40
        self.assertTrue(any("built_from_commit must match" in error for error in validate_audit(item)))

    def test_stale_evidence_must_exclude_historical_records(self):
        item = audit()
        item["stale_evidence"]["historical_records_excluded"] = False
        self.assertTrue(any("historical_records_excluded must be true" in error for error in validate_audit(item)))

    def test_native_not_run_cannot_carry_platform(self):
        item = audit()
        item["native_execution"]["platform"] = "Windows"
        self.assertTrue(any("platform must be null" in error for error in validate_audit(item)))


if __name__ == "__main__":
    unittest.main()
