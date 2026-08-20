"""Focused tests for the production settings coverage evidence gate."""

import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import production_settings_coverage_manifest as validator  # noqa: E402


FIXTURE = Path(__file__).with_name("production_settings_coverage_manifest.json")


class ProductionSettingsCoverageTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_checked_in_manifest_is_valid(self):
        self.assertEqual(validator.validate_manifest(self.data), [])

    def test_action_roster_and_sections_are_complete(self):
        value = copy.deepcopy(self.data)
        value["action_roster"]["covered_actions"] = value["action_roster"]["covered_actions"][:-1]
        errors = validator.validate_manifest(value)
        self.assertTrue(any("covered_actions" in error for error in errors))

    def test_hardware_status_is_explicit_and_pass_requires_evidence(self):
        value = copy.deepcopy(self.data)
        value["hardware"]["status"] = "PASSED"
        errors = validator.validate_manifest(value)
        self.assertIn("hardware.evidence is required when status is PASSED", errors)

    def test_invalid_ultrawide_or_transform_contract_fails(self):
        value = copy.deepcopy(self.data)
        value["ultrawide"]["aspect_ratios"] = ["16:9"]
        value["curve_hold_toggle"]["modes"] = ["hold"]
        errors = validator.validate_manifest(value)
        self.assertTrue(any("ultrawide.aspect_ratios missing" in error for error in errors))
        self.assertTrue(any("curve_hold_toggle.modes missing" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
