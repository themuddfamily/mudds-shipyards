"""Focused tests for the settings/accessibility matrix evidence gate."""

import copy
import json
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import settings_accessibility_matrix_validator as validator  # noqa: E402


FIXTURE = Path(__file__).with_name("settings_accessibility_matrix.json")


class SettingsAccessibilityMatrixTests(unittest.TestCase):
    def setUp(self):
        self.data = json.loads(FIXTURE.read_text(encoding="utf-8"))

    def test_checked_in_matrix_is_valid(self):
        self.assertEqual(validator.validate_manifest(self.data), [])

    def test_missing_glyph_and_aspect_entries_fail(self):
        value = copy.deepcopy(self.data)
        value["glyphs"]["families"] = ["keyboard"]
        value["ultrawide"]["aspect_ratios"] = ["16:9"]
        errors = validator.validate_manifest(value)
        self.assertTrue(any("glyphs.families missing" in error for error in errors))
        self.assertTrue(any("ultrawide.aspect_ratios missing" in error for error in errors))

    def test_hardware_status_is_explicit_and_pass_requires_evidence(self):
        value = copy.deepcopy(self.data)
        value["hardware"]["status"] = "PASSED"
        errors = validator.validate_manifest(value)
        self.assertIn("hardware.evidence is required when status is PASSED", errors)

    def test_remapping_and_subtitle_contracts_fail_closed(self):
        value = copy.deepcopy(self.data)
        value["remapping"]["conflict_resolution"] = "yes"
        value["subtitles"]["modes"] = ["off"]
        errors = validator.validate_manifest(value)
        self.assertIn("remapping.conflict_resolution must be a boolean", errors)
        self.assertTrue(any("subtitles.modes missing" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
