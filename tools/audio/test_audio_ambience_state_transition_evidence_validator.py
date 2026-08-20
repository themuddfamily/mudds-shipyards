"""Focused tests for ambience state-transition action evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_ambience_state_transition_evidence_validator as validator  # noqa: E402


def state(name: str) -> dict:
    return {"name": name, "entry_evidence": f"artifacts/audio/{name}-entry.json", "exit_evidence": f"artifacts/audio/{name}-exit.json", "voice_owner": "presentation_only"}


def transition(source: str, target: str) -> dict:
    return {"from": source, "to": target, "actions": ["fade_out", "fade_in", "retain"], "evidence": f"artifacts/audio/{source}-{target}-actions.json", "authority": "presentation_only"}


def ledger() -> dict:
    return {"schema": "audio_ambience_state_transition_evidence_v1", "revision": "a" * 40, "owner": "ambience-state-owner", "evidence_bundle": "artifacts/audio/ambience-actions.json", "native_audition": "OPEN", "claim": "AUTOMATED_TRANSITION_ONLY", "boundary_note": "No native audition has occurred.", "states": [state(name) for name in sorted(validator.STATES)], "transitions": [transition(*pair) for pair in sorted(validator.REQUIRED_PATHS)]}


class AudioAmbienceStateTransitionEvidenceTests(unittest.TestCase):
    def test_complete_transition_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_missing_path_is_rejected(self):
        value = copy.deepcopy(ledger())
        value["transitions"] = value["transitions"][:-1]
        errors = validator.validate_ledger(value)
        self.assertIn("transitions missing required ambience paths", errors)

    def test_actions_and_presentation_authority_are_required(self):
        value = copy.deepcopy(ledger())
        value["transitions"][0]["actions"] = ["unknown"]
        value["transitions"][0]["authority"] = "gameplay"
        errors = validator.validate_ledger(value)
        self.assertIn("transitions[0].actions must be a unique list of supported actions", errors)
        self.assertIn("transitions[0].authority must be presentation_only", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
