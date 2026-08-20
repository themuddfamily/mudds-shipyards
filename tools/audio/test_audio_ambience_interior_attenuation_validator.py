"""Focused tests for ambience interior attenuation evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_ambience_interior_attenuation_validator as validator  # noqa: E402


def context(name: str, attenuation: float) -> dict:
    return {"context": name, "interior_attenuation_db": attenuation, "policy_evidence": f"artifacts/audio/{name}-policy.json", "routing_evidence": f"artifacts/audio/{name}-route.json", "bus": "Ambience", "positional": False}


def manifest() -> dict:
    return {"schema": "audio_ambience_interior_attenuation_v1", "revision": "a" * 40, "owner": "planetary-audio-owner", "evidence_bundle": "artifacts/audio/attenuation.json", "native_audition": "OPEN", "claim": "AUTOMATED_ATTENUATION_ONLY", "boundary_note": "No native audition has occurred.", "contexts": [context("exterior", 0.0), context("interior", -8.0), context("cabin", -8.0)]}


class AudioAmbienceInteriorAttenuationTests(unittest.TestCase):
    def test_valid_context_attenuation(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_exterior_and_interior_endpoints_are_distinct(self):
        value = copy.deepcopy(manifest())
        value["contexts"][0]["interior_attenuation_db"] = -3.0
        value["contexts"][1]["interior_attenuation_db"] = 0.0
        errors = validator.validate_manifest(value)
        self.assertIn("contexts[0].exterior attenuation must be exactly 0 dB", errors)
        self.assertIn("contexts[1].interior attenuation must be below 0 dB", errors)

    def test_bus_and_positional_contract_are_required(self):
        value = copy.deepcopy(manifest())
        value["contexts"][0]["bus"] = "SFX"
        value["contexts"][1]["positional"] = True
        errors = validator.validate_manifest(value)
        self.assertIn("contexts[0].bus must be Ambience", errors)
        self.assertIn("contexts[1].positional must be false", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(manifest())
        value["native_audition"] = "PASS"
        errors = validator.validate_manifest(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
