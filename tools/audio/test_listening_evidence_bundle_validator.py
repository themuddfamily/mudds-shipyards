"""Focused tests for the cross-feature audio listening evidence gate."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import listening_evidence_bundle_validator as validator  # noqa: E402


def bundle() -> dict:
    review = {"status": "PASS", "reviewer": "operator-1", "device": "reference-headphones", "evidence": "artifacts/audio/review.json", "notes": "No clipping or masking."}
    return {
        "schema_version": 1,
        "bundle_id": "audio-listening-v1",
        "build_label": "v0.12-candidate",
        "source_commit": "a" * 40,
        "claim": "HUMAN_LISTENING_PASS",
        "music": {"asset_ids": ["station-rest-v1", "station-rest-v2"], "bus": "Music", "state_checks": ["station_rest", "encounter", "return"], "lifecycle_evidence": "artifacts/audio/music-lifecycle.json", "listening": {**review, "backend": "native_output"}},
        "mix": {"backend": "native_output", "device": "reference-headphones", "scenarios": ["station", "combat", "return"], "capture_evidence": "artifacts/audio/mix-capture.json", "listening": {**review, "backend": "native_output"}},
        "accessibility": {"captions": True, "caption_scenarios": ["radio", "combat", "ambient"], "audio_alternatives": ["captioned_cue", "visual_state_cue"], "layout_evidence": "artifacts/ui/caption-review.json", "review": review},
    }


class ListeningEvidenceBundleTests(unittest.TestCase):
    def test_valid_complete_native_bundle(self):
        self.assertEqual(validator.validate_bundle(bundle()), [])

    def test_automated_only_requires_explicit_boundary(self):
        value = copy.deepcopy(bundle())
        value["claim"] = "AUTOMATED_ONLY"
        value["boundary_note"] = "Dummy audio and layout assertions do not establish audibility."
        self.assertEqual(validator.validate_bundle(value), [])

    def test_missing_state_and_caption_alternative_fail_closed(self):
        value = copy.deepcopy(bundle())
        value["music"]["state_checks"] = ["station_rest"]
        value["accessibility"]["audio_alternatives"] = []
        errors = validator.validate_bundle(value)
        self.assertIn("bundle.music.state_checks must cover station_rest, encounter, and return", errors)
        self.assertIn("bundle.accessibility.audio_alternatives must be a non-empty unique array", errors)

    def test_dummy_backend_cannot_claim_human_pass(self):
        value = copy.deepcopy(bundle())
        value["claim"] = "HUMAN_LISTENING_PASS"
        value["mix"]["backend"] = "dummy"
        value["mix"]["listening"]["backend"] = "dummy"
        value["mix"]["listening"]["status"] = "OUTSTANDING"
        value["mix"]["listening"]["notes"] = "Native output device was unavailable."
        errors = validator.validate_bundle(value)
        self.assertIn("bundle.claim HUMAN_LISTENING_PASS requires native audio and three PASS reviews", errors)

    def test_mix_review_backend_must_match(self):
        value = copy.deepcopy(bundle())
        value["mix"]["listening"]["backend"] = "dummy"
        errors = validator.validate_bundle(value)
        self.assertIn("bundle.mix.listening.backend must match mix.backend", errors)


if __name__ == "__main__":
    unittest.main()
