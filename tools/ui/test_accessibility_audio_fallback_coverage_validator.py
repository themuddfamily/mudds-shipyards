"""Focused tests for accessibility audio fallback coverage."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import accessibility_audio_fallback_coverage_validator as validator  # noqa: E402


def family(name: str) -> dict:
    return {"family": name, "status": "AUTOMATED_PASS", "fallback_channels": ["captions", "visual_state"], "cue_ids": [f"cue:{name}:primary"], "contract_evidence": [f"artifacts/ui/{name}-fallback.json"]}


def ledger() -> dict:
    return {"schema": "accessibility_audio_fallback_coverage_v1", "source": {"revision": "a" * 40, "caption_owner": "caption_presenter", "evidence_bundle": "artifacts/ui/audio-fallback.json"}, "hardware_review": "OPEN", "claim": "AUTOMATED_FALLBACK_ONLY", "boundary_note": "Automated caption/layout checks do not establish physical-device readability.", "families": [family(name) for name in sorted(validator.REQUIRED_FAMILIES)]}


class AccessibilityAudioFallbackCoverageTests(unittest.TestCase):
    def test_complete_automated_coverage(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_missing_family_and_channel_fail_closed(self):
        value = copy.deepcopy(ledger())
        value["families"] = value["families"][:-1]
        value["families"][0]["fallback_channels"] = ["captions"]
        errors = validator.validate_ledger(value)
        self.assertTrue(any("fallback_channels must include captions and visual_state" in error for error in errors))
        self.assertIn("families must cover: ui_feedback", errors)

    def test_duplicate_family_and_missing_contract_evidence_are_rejected(self):
        value = copy.deepcopy(ledger())
        value["families"][1]["family"] = value["families"][0]["family"]
        value["families"][1]["contract_evidence"] = []
        errors = validator.validate_ledger(value)
        self.assertIn("families[1].family is duplicated", errors)
        self.assertIn("families[1].contract_evidence must be a non-empty unique list of paths/IDs", errors)

    def test_physical_pass_claim_is_not_automated_evidence(self):
        value = copy.deepcopy(ledger())
        value["hardware_review"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("hardware_review must be OPEN until physical review is recorded", errors)


if __name__ == "__main__":
    unittest.main()
