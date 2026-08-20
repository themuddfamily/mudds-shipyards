"""Focused tests for planetary audio route/profile coverage."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import planetary_audio_route_coverage_validator as validator  # noqa: E402


def profile(context: str) -> dict:
    alias = "interior" if context == "cabin" else context
    return {"context": context, "context_alias": alias, "profile_id": f"temperate_{alias}", "asset_path": f"assets/audio/planetary/{alias}.wav", "bus": "Ambience", "positional": False, "base_gain_db": -12.0, "selection_evidence": f"artifacts/audio/planetary/{context}.json"}


def manifest() -> dict:
    return {"schema": "planetary_audio_route_coverage_v1", "revision": "a" * 40, "world_id": "ember_caldera", "catalog_evidence": "artifacts/audio/planetary-catalog.json", "routing_evidence": "artifacts/audio/planetary-routing.json", "native_audition": "OPEN", "boundary_note": "Native audition remains open.", "claim": "AUTOMATED_ROUTE_ONLY", "profiles": [profile(context) for context in sorted(validator.REQUIRED_CONTEXTS)]}


class PlanetaryAudioRouteCoverageTests(unittest.TestCase):
    def test_complete_context_route_coverage(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_context_alias_and_bus_are_frozen(self):
        value = copy.deepcopy(manifest())
        value["profiles"][0]["context_alias"] = "exterior"
        value["profiles"][1]["bus"] = "SFX"
        errors = validator.validate_manifest(value)
        self.assertIn("profiles[0].context_alias is invalid", errors)
        self.assertIn("profiles[1].bus must be Ambience", errors)

    def test_positional_and_gain_bounds_are_rejected(self):
        value = copy.deepcopy(manifest())
        value["profiles"][0]["positional"] = True
        value["profiles"][1]["base_gain_db"] = 7.0
        errors = validator.validate_manifest(value)
        self.assertIn("profiles[0].positional must be false", errors)
        self.assertIn("profiles[1].base_gain_db must be between -80 and 6 dB", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(manifest())
        value["native_audition"] = "PASS"
        errors = validator.validate_manifest(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
