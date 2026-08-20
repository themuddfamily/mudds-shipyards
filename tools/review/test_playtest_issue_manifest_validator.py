import json
import tempfile
import unittest
from pathlib import Path

from tools.review.playtest_issue_manifest_validator import validate


class PlaytestIssueManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)

    def tearDown(self):
        self.tmp.cleanup()

    def manifest(self, **changes):
        value = {
            "schema": "playtest_issue_manifest_v1",
            "human_run_status": "NOT_RUN",
            "human_run_evidence": None,
            "issues": [{"id": "MAP-001", "severity": "P1", "title": "blocked route",
                        "repro_steps": ["launch package", "walk to berth"],
                        "evidence": ["capture://map-001"], "status": "open"}],
        }
        value.update(changes)
        path = self.root / "playtest.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        return path

    def test_valid_not_run_manifest_is_explicit(self):
        self.assertEqual(validate(self.manifest()), [])

    def test_run_requires_human_evidence(self):
        errors = validate(self.manifest(human_run_status="COMPLETE"))
        self.assertTrue(any("human_run_evidence is required" in error for error in errors))

    def test_not_run_cannot_claim_evidence(self):
        errors = validate(self.manifest(human_run_evidence="operator notes"))
        self.assertTrue(any("must be null" in error for error in errors))

    def test_closed_p1_requires_all_closure_evidence(self):
        issue = self.manifest().read_text()
        value = json.loads(issue)
        value["issues"][0]["status"] = "closed"
        path = self.root / "closed.json"
        path.write_text(json.dumps(value))
        errors = validate(path)
        self.assertTrue(any("closure is required" in error for error in errors))

    def test_steps_evidence_severity_and_duplicate_ids_are_checked(self):
        value = json.loads(self.manifest().read_text())
        value["issues"][0].update({"severity": "P3", "repro_steps": [], "evidence": [], "id": "X"})
        value["issues"].append(dict(value["issues"][0]))
        path = self.root / "invalid.json"
        path.write_text(json.dumps(value))
        errors = validate(path)
        self.assertTrue(any("severity" in error for error in errors))
        self.assertTrue(any("repro_steps" in error for error in errors))
        self.assertTrue(any("evidence" in error for error in errors))
        self.assertTrue(any("unique" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
