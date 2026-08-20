"""Focused tests for authored-audio coverage validation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import authored_audio_coverage_validator as validator  # noqa: E402


def asset(category: str, index: int) -> dict:
    return {"asset_id": f"audio-{category}-{index}", "category": category, "paths": [f"assets/audio/{category}/cue-{index}.wav"], "sha256": (str(index) * 64)[:64], "generator_or_source": "project-original generator", "bus": "Music" if category == "music" else "SFX", "runtime_evidence": f"artifacts/audio/{category}-route.json", "status": "CHECKED_IN"}


def manifest() -> dict:
    return {"schema": "authored_audio_coverage_v1", "source": {"revision": "a" * 40, "provenance_owner": "audio-owner"}, "claim": "AUTOMATED_COVERAGE_ONLY", "assets": [asset(category, index) for index, category in enumerate(sorted(validator.CATEGORIES), 1)], "human_audition": {"status": "OPEN", "boundary_note": "No human audition has occurred on this host."}}


class AuthoredAudioCoverageTests(unittest.TestCase):
    def test_complete_checked_in_coverage(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_missing_category_and_duplicate_identity_fail(self):
        value = copy.deepcopy(manifest())
        value["assets"] = value["assets"][:-1]
        value["assets"][1]["asset_id"] = value["assets"][0]["asset_id"]
        errors = validator.validate_manifest(value)
        self.assertIn("assets[1].asset_id is duplicated", errors)
        self.assertIn("assets must cover categories: ui", errors)

    def test_missing_digest_and_runtime_route_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["assets"][0]["sha256"] = "bad"
        value["assets"][0]["runtime_evidence"] = ""
        errors = validator.validate_manifest(value)
        self.assertIn("assets[0].sha256 must be a lowercase 64-character digest", errors)
        self.assertIn("assets[0].runtime_evidence is required", errors)

    def test_automated_claim_cannot_hide_human_pass(self):
        value = copy.deepcopy(manifest())
        value["human_audition"] = {"status": "PASS", "reviewer": "operator", "device": "headphones", "evidence": "artifacts/audio/listening.json", "notes": "Reviewed."}
        errors = validator.validate_manifest(value)
        self.assertIn("AUTOMATED_COVERAGE_ONLY cannot contain a human_audition PASS", errors)


if __name__ == "__main__":
    unittest.main()
