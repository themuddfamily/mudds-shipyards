"""Focused tests for ultrawide/caption evidence boundaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ultrawide_caption_evidence_ledger_validator as validator  # noqa: E402


def ledger() -> dict:
    return {
        "schema": "ultrawide_caption_evidence_v1",
        "source": {"revision": "a" * 40, "layout_owner": "caption_presenter.tscn"},
        "hardware_review": "OPEN",
        "claim": "AUTOMATED_LAYOUT_ONLY",
        "boundary_note": "Headless layout checks do not establish readability on physical displays.",
        "ultrawide": {"status": "AUTOMATED_PASS", "aspect_ratios": ["16:9", "16:10", "21:9", "32:9"], "safe_area_evidence": ["artifacts/ui/safe-area.json"], "focus_evidence": ["artifacts/ui/focus.json"]},
        "captions": {"status": "AUTOMATED_PASS", "scenarios": ["radio", "combat", "ambient"], "viewport_evidence": ["artifacts/ui/caption-layout.json"], "contrast_evidence": ["artifacts/ui/caption-contrast.json"], "contract": {"minimum_scale": 0.75, "maximum_scale": 1.6, "minimum_contrast_ratio": 7.0, "maximum_text_characters": 512}},
    }


class UltrawideCaptionEvidenceTests(unittest.TestCase):
    def test_valid_automated_ledger_keeps_hardware_open(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_aspect_and_caption_evidence_are_required(self):
        value = copy.deepcopy(ledger())
        value["ultrawide"]["aspect_ratios"] = ["16:9"]
        value["captions"]["contrast_evidence"] = []
        errors = validator.validate_ledger(value)
        self.assertIn("ultrawide.aspect_ratios must cover 16:9, 16:10, 21:9, and 32:9", errors)
        self.assertIn("captions.contrast_evidence must be a non-empty unique list of paths", errors)

    def test_human_pass_cannot_be_claimed_before_device_review(self):
        value = copy.deepcopy(ledger())
        value["claim"] = "HUMAN_PRESENTATION_PASS"
        value["ultrawide"]["status"] = "HUMAN_PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("ultrawide.status HUMAN_PASS is not allowed while hardware_review is OPEN", errors)
        self.assertIn("claim HUMAN_PRESENTATION_PASS is blocked while hardware_review is OPEN", errors)

    def test_caption_contract_range_is_fail_closed(self):
        value = copy.deepcopy(ledger())
        value["captions"]["contract"]["minimum_scale"] = 2.0
        value["captions"]["contract"]["maximum_scale"] = 1.0
        errors = validator.validate_ledger(value)
        self.assertIn("captions.contract.minimum_scale must be less than maximum_scale", errors)


if __name__ == "__main__":
    unittest.main()
