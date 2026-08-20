"""Focused tests for planetary ambience gain/profile evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import planetary_ambience_gain_profile_validator as validator  # noqa: E402


def profile(profile_id: str) -> dict:
    return {"profile_id": profile_id, "asset_path": f"assets/audio/planetary/{profile_id}.wav", "catalog_evidence": f"artifacts/audio/{profile_id}-catalog.json", "base_gain_db": -12.0, "wind_min_gain_db": -30.0, "wind_max_gain_db": -6.0, "landing_gain_db": -18.0, "interior_attenuation_db": -8.0, "bus": "Ambience", "positional": False}


def manifest() -> dict:
    return {"schema": "planetary_ambience_gain_profile_v1", "revision": "a" * 40, "world_id": "ember_caldera", "policy_evidence": "artifacts/audio/planetary-policy.json", "routing_evidence": "artifacts/audio/planetary-routing.json", "native_audition": "OPEN", "claim": "AUTOMATED_GAIN_ONLY", "boundary_note": "Gain evidence does not establish native audibility.", "profiles": [profile(profile_id) for profile_id in sorted(validator.REQUIRED_PROFILES)]}


class PlanetaryAmbienceGainProfileTests(unittest.TestCase):
    def test_valid_gain_profiles(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_wind_range_and_interior_attenuation_are_bounded(self):
        value = copy.deepcopy(manifest())
        value["profiles"][0]["wind_min_gain_db"] = 0.0
        value["profiles"][0]["wind_max_gain_db"] = -10.0
        value["profiles"][1]["interior_attenuation_db"] = 2.0
        errors = validator.validate_manifest(value)
        self.assertIn("profiles[0].wind_min_gain_db must not exceed wind_max_gain_db", errors)
        self.assertIn("profiles[1].interior_attenuation_db must be non-positive and bounded", errors)

    def test_missing_profile_and_wrong_bus_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["profiles"] = value["profiles"][:1]
        value["profiles"][0]["bus"] = "SFX"
        errors = validator.validate_manifest(value)
        self.assertIn("profiles[0].bus must be Ambience", errors)
        self.assertIn("profiles must cover: temperate_interior", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(manifest())
        value["native_audition"] = "PASS"
        errors = validator.validate_manifest(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
