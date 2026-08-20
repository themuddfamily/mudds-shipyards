"""Focused tests for music transition evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import music_state_transition_evidence_validator as validator  # noqa: E402


def state(state_id: str) -> dict:
    return {"id": state_id, "entry_evidence": f"artifacts/audio/{state_id}-entry.json", "exit_evidence": f"artifacts/audio/{state_id}-exit.json", "bus": "Music", "silences_on_encounter": True, "retains_position_on_reentry": True}


def transition(source: str, target: str) -> dict:
    return {"from": source, "to": target, "trigger_evidence": f"artifacts/audio/{source}-{target}-trigger.json", "result_evidence": f"artifacts/audio/{source}-{target}-result.json", "presentation_only": True}


def record() -> dict:
    return {"schema": "music_state_transition_evidence_v1", "revision": "a" * 40, "music_owner": "station_music_bed", "evidence_bundle": "artifacts/audio/music-state.json", "audition_status": "OPEN", "audition_boundary": "No human audition has occurred.", "states": [state(item) for item in sorted(validator.REQUIRED_STATES)], "transitions": [transition(*pair) for pair in sorted(validator.REQUIRED_TRANSITIONS)], "authority_exclusions": ["gameplay_phase", "damage", "reward"]}


class MusicStateTransitionEvidenceTests(unittest.TestCase):
    def test_valid_open_audition_record(self):
        self.assertEqual(validator.validate_record(record()), [])

    def test_missing_transition_path_is_rejected(self):
        value = copy.deepcopy(record())
        value["transitions"] = value["transitions"][:-1]
        errors = validator.validate_record(value)
        self.assertIn("transitions missing required state paths", errors)

    def test_transition_must_remain_presentation_only(self):
        value = copy.deepcopy(record())
        value["transitions"][0]["presentation_only"] = False
        errors = validator.validate_record(value)
        self.assertIn("transitions[0].presentation_only must be true", errors)

    def test_pass_requires_audition_evidence(self):
        value = copy.deepcopy(record())
        value["audition_status"] = "PASS"
        errors = validator.validate_record(value)
        self.assertIn("audition_evidence is required for PASS", errors)


if __name__ == "__main__":
    unittest.main()
