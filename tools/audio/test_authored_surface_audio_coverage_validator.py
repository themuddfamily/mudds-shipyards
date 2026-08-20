"""Focused tests for authored planetary surface-audio coverage."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import authored_surface_audio_coverage_validator as validator  # noqa: E402


def profile(context: str, index: int) -> dict:
    checked = context in {"exterior", "interior"}
    value = {"context": context, "profile_id": f"surface-{context}", "bus": "Ambience", "routing_evidence": f"artifacts/audio/{context}-route.json", "policy_evidence": f"artifacts/audio/{context}-policy.json", "status": "CHECKED_IN" if checked else "CONTRACT_ONLY"}
    if checked:
        value["asset_paths"] = [f"assets/audio/planetary/{context}-v1.wav"]
    return value


def manifest() -> dict:
    return {"schema": "authored_surface_audio_coverage_v1", "revision": "a" * 40, "world_id": "ember_caldera", "catalog_evidence": "artifacts/audio/planetary-catalog.json", "claim": "AUTOMATED_SURFACE_COVERAGE_ONLY", "audition_status": "OPEN", "audition_boundary": "Native audition remains open.", "profiles": [profile(context, index) for index, context in enumerate(sorted(validator.REQUIRED_CONTEXTS))]}


class AuthoredSurfaceAudioCoverageTests(unittest.TestCase):
    def test_valid_mixed_asset_and_contract_coverage(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_missing_context_and_bad_route_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["profiles"] = value["profiles"][:-1]
        value["profiles"][0]["routing_evidence"] = ""
        errors = validator.validate_manifest(value)
        self.assertIn("profiles[0].routing_evidence is required", errors)
        self.assertIn("profiles must cover: weather_response", errors)

    def test_contract_only_profile_cannot_have_asset_path(self):
        value = copy.deepcopy(manifest())
        contract = next(item for item in value["profiles"] if item["status"] == "CONTRACT_ONLY")
        contract["asset_paths"] = ["assets/audio/planetary/future.wav"]
        errors = validator.validate_manifest(value)
        self.assertTrue(any("asset_paths must be empty for CONTRACT_ONLY" in error for error in errors))

    def test_automated_claim_cannot_hide_audition_pass(self):
        value = copy.deepcopy(manifest())
        value["audition_status"] = "PASS"
        errors = validator.validate_manifest(value)
        self.assertIn("AUTOMATED_SURFACE_COVERAGE_ONLY cannot claim human audition PASS", errors)


if __name__ == "__main__":
    unittest.main()
