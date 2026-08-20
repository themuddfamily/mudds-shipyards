"""Focused tests for landing/cabin profile endpoint evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_profile_endpoint_validator as validator  # noqa: E402


def profile(name: str) -> dict:
    return {"name": name, "asset_id": f"surface:{name}", "catalog_evidence": f"artifacts/audio/{name}-catalog.json", "endpoint_evidence": f"artifacts/audio/{name}-endpoints.json", "bus": "Ambience", "positional": False, "entry_gain_db": -24.0, "steady_gain_db": -12.0, "exit_gain_db": -80.0}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_profile_endpoint_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/landing-cabin-endpoints.json", "native_audition": "OPEN", "claim": "AUTOMATED_ENDPOINT_ONLY", "boundary_note": "No native audition has occurred.", "profiles": [profile(name) for name in sorted(validator.PROFILES)]}


class AudioLandingCabinEndpointTests(unittest.TestCase):
    def test_complete_endpoint_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_stop_endpoint_and_gain_order_are_required(self):
        value = copy.deepcopy(ledger())
        value["profiles"][0]["exit_gain_db"] = -60.0
        value["profiles"][1]["entry_gain_db"] = 0.0
        value["profiles"][1]["steady_gain_db"] = -12.0
        errors = validator.validate_ledger(value)
        self.assertIn("profiles[0].exit_gain_db must be -80 dB stop endpoint", errors)
        self.assertIn("profiles[1].entry_gain_db must not exceed steady_gain_db", errors)

    def test_bus_and_positional_contract_are_required(self):
        value = copy.deepcopy(ledger())
        value["profiles"][0]["bus"] = "SFX"
        value["profiles"][1]["positional"] = True
        errors = validator.validate_ledger(value)
        self.assertIn("profiles[0].bus must be Ambience", errors)
        self.assertIn("profiles[1].positional must be false", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
