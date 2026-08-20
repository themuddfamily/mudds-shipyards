"""Focused tests for UI audio/caption prompt consistency."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_caption_prompt_consistency_validator as validator  # noqa: E402


def prompt(category: str, index: int) -> dict:
    return {"cue_id": f"cue:{category}:{index}", "category": category, "audio_route": "UI", "caption_category": category, "caption_text": f"{category.title()} cue", "visual_token": f"shape_{index}", "fallback_channels": ["captions", "visual_state"], "evidence": f"artifacts/ui/{category}-prompt.json"}


def manifest() -> dict:
    return {"schema": "audio_caption_prompt_consistency_v1", "revision": "a" * 40, "prompt_owner": "hud-prompt-owner", "evidence_bundle": "artifacts/ui/prompt-consistency.json", "hardware_review": "OPEN", "claim": "AUTOMATED_CONSISTENCY_ONLY", "boundary_note": "Automated mapping does not establish readability on hardware.", "prompts": [prompt(category, index) for index, category in enumerate(sorted(validator.REQUIRED_CATEGORIES), 1)]}


class AudioCaptionPromptConsistencyTests(unittest.TestCase):
    def test_complete_prompt_mapping(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_category_and_caption_category_must_match(self):
        value = copy.deepcopy(manifest())
        value["prompts"][0]["caption_category"] = "warning"
        errors = validator.validate_manifest(value)
        self.assertIn("prompts[0].caption_category must match category", errors)

    def test_colour_only_visual_fallback_is_rejected(self):
        value = copy.deepcopy(manifest())
        value["prompts"][1]["visual_token"] = "colour_only"
        errors = validator.validate_manifest(value)
        self.assertIn("prompts[1].visual_token must be a non-colour cue", errors)

    def test_missing_category_and_caption_channel_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["prompts"] = value["prompts"][:-1]
        value["prompts"][0]["fallback_channels"] = ["captions"]
        errors = validator.validate_manifest(value)
        self.assertIn("prompts[0].fallback_channels must include unique captions and visual_state", errors)
        self.assertIn("prompts must cover: warning", errors)


if __name__ == "__main__":
    unittest.main()
