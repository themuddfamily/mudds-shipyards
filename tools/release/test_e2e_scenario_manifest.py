#!/usr/bin/env python3
"""Focused contract tests for the end-to-end scenario manifest gate."""

from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parent))
import e2e_scenario_manifest as validator  # noqa: E402


MANIFEST_PATH = Path(__file__).with_name("e2e_scenario_manifest.json")


def manifest() -> dict:
    return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))


class E2EScenarioManifestTests(unittest.TestCase):
    def test_checked_in_manifest_is_valid_pending_planning_evidence(self):
        record = manifest()
        self.assertEqual(validator.validate_manifest(record), [])
        self.assertEqual(record["scenarios"][0]["evidence"]["status"], "pending")

    def test_reentry_preserve_and_reset_overlap_fails_closed(self):
        record = manifest()
        record["scenarios"][0]["reentry"]["reset_fields"].append("activity_progress")
        errors = validator.validate_manifest(record)
        self.assertTrue(any("preserved_fields and reset_fields overlap" in error for error in errors))

    def test_out_of_order_or_duplicate_steps_fail(self):
        record = manifest()
        steps = record["scenarios"][0]["steps"]
        steps[4], steps[5] = steps[5], steps[4]
        steps.append(copy.deepcopy(steps[0]))
        errors = validator.validate_manifest(record)
        self.assertTrue(any("out of lifecycle order" in error for error in errors))
        self.assertTrue(any("step ids must be unique" in error for error in errors))

    def test_pass_evidence_requires_source_package_and_fresh_runs(self):
        record = manifest()
        evidence = record["scenarios"][0]["evidence"]
        evidence["status"] = "pass"
        evidence["package"] = "pass"
        evidence["source_commit"] = "a" * 40
        evidence["runs"] = [{"id": "run-1", "result": "pass", "fresh_process": True}]
        errors = validator.validate_manifest(record)
        self.assertTrue(
            any("needs at least 3 passing fresh-process runs" in error for error in errors)
        )

    def test_recorded_source_requires_clean_commit(self):
        record = manifest()
        record["source"] = {"status": "recorded", "git_sha": "b" * 40, "git_dirty": True}
        errors = validator.validate_manifest(record)
        self.assertIn("recorded source requires git_sha and git_dirty=false", errors)


if __name__ == "__main__":
    unittest.main()
