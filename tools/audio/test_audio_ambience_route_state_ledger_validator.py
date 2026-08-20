"""Focused tests for ambience route/attenuation state ledger."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_ambience_route_state_ledger_validator as validator  # noqa: E402


def state(name: str) -> dict:
    return {"name": name, "bus": "Ambience", "gain_db": -12.0, "attenuation_db": 0.0 if name == "exterior" else -8.0, "evidence": f"artifacts/audio/ambience-{name}.json"}


def transition(source: str, target: str) -> dict:
    return {"from": source, "to": target, "fade_seconds": 0.75, "evidence": f"artifacts/audio/{source}-{target}-fade.json", "presentation_only": True}


def ledger() -> dict:
    return {"schema": "audio_ambience_route_state_ledger_v1", "revision": "a" * 40, "owner": "ambience-route-owner", "evidence_bundle": "artifacts/audio/ambience-state.json", "native_audition": "OPEN", "claim": "AUTOMATED_ROUTE_STATE_ONLY", "boundary_note": "No native audition has occurred.", "states": [state(name) for name in sorted(validator.STATES)], "transitions": [transition(*pair) for pair in sorted(validator.TRANSITIONS)]}


class AudioAmbienceRouteStateLedgerTests(unittest.TestCase):
    def test_complete_state_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_missing_ambience_path_is_rejected(self):
        value = copy.deepcopy(ledger())
        value["transitions"] = value["transitions"][:-1]
        errors = validator.validate_ledger(value)
        self.assertIn("transitions missing required ambience paths", errors)

    def test_fade_and_presentation_bounds_are_enforced(self):
        value = copy.deepcopy(ledger())
        value["transitions"][0]["fade_seconds"] = 2.1
        value["transitions"][0]["presentation_only"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("transitions[0].fade_seconds must be greater than 0 and at most 2", errors)
        self.assertIn("transitions[0].presentation_only must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
