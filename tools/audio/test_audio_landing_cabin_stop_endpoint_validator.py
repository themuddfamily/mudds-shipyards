"""Focused tests for landing/cabin ambience stop-endpoint evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_stop_endpoint_validator as validator  # noqa: E402


def endpoint(name: str) -> dict:
    return {"name": name, "trigger": f"event:{name}", "terminal_gain_db": -80, "bus": "Ambience", "stop_evidence": f"artifacts/audio/{name}-stop.json", "route_evidence": f"artifacts/audio/{name}-route.json", "stops_voice": True, "clears_binding": True, "presentation_only": True}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_stop_endpoint_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/stop-endpoints.json", "native_audition": "OPEN", "claim": "AUTOMATED_STOP_ONLY", "boundary_note": "No native audition has occurred.", "endpoints": [endpoint(name) for name in sorted(validator.REQUIRED_ENDPOINTS)]}


class AudioLandingCabinStopEndpointTests(unittest.TestCase):
    def test_complete_stop_endpoint_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_terminal_gain_and_cleanup_flags_are_required(self):
        value = copy.deepcopy(ledger())
        value["endpoints"][0]["terminal_gain_db"] = -60
        value["endpoints"][1]["clears_binding"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("endpoints[0].terminal_gain_db must be -80 dB", errors)
        self.assertIn("endpoints[1].clears_binding must be true", errors)

    def test_missing_endpoint_and_wrong_bus_fail_closed(self):
        value = copy.deepcopy(ledger())
        value["endpoints"] = value["endpoints"][:-1]
        value["endpoints"][0]["bus"] = "SFX"
        errors = validator.validate_ledger(value)
        self.assertIn("endpoints[0].bus must be Ambience", errors)
        self.assertIn("endpoints must cover: source_detach", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
