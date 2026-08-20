"""Focused tests for cabin/landing ambience transition evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_ambience_cabin_landing_transition_validator as validator  # noqa: E402


def state(name: str) -> dict:
    return {"name": name, "bus": "Ambience", "authority": "presentation_only", "evidence": f"artifacts/audio/{name}.json"}


def transition(source: str, target: str) -> dict:
    return {"from": source, "to": target, "actions": ["fade_out", "fade_in", "retain"], "evidence": f"artifacts/audio/{source}-{target}.json", "authority": "presentation_only"}


def ledger() -> dict:
    return {"schema": "audio_ambience_cabin_landing_transition_v1", "revision": "a" * 40, "owner": "cabin-landing-audio-owner", "evidence_bundle": "artifacts/audio/cabin-landing.json", "native_audition": "OPEN", "claim": "AUTOMATED_CABIN_LANDING_ONLY", "boundary_note": "Native audition remains open.", "states": [state(name) for name in sorted(validator.STATES)], "transitions": [transition(*pair) for pair in sorted(validator.PATHS)]}


class AudioAmbienceCabinLandingTests(unittest.TestCase):
    def test_complete_cabin_landing_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_missing_touchdown_path_is_rejected(self):
        value = copy.deepcopy(ledger())
        value["transitions"] = value["transitions"][:-1]
        errors = validator.validate_ledger(value)
        self.assertIn("transitions missing required cabin/landing paths", errors)

    def test_actions_and_authority_are_presentation_only(self):
        value = copy.deepcopy(ledger())
        value["transitions"][0]["actions"] = ["gameplay_damage"]
        value["transitions"][0]["authority"] = "gameplay"
        errors = validator.validate_ledger(value)
        self.assertIn("transitions[0].actions must be unique supported actions", errors)
        self.assertIn("transitions[0].authority must be presentation_only", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
