"""Focused tests for audio bus gain/fade transition evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_bus_fade_transition_evidence_validator as validator  # noqa: E402


def transition(source: str, target: str, bus: str) -> dict:
    return {"from": source, "to": target, "bus": bus, "from_gain_db": -6.0, "to_gain_db": -18.0, "fade_seconds": 0.75, "evidence": f"artifacts/audio/{source}-{target}-{bus}.json", "presentation_only": True}


def record() -> dict:
    return {"schema": "audio_bus_fade_transition_evidence_v1", "revision": "a" * 40, "mix_owner": "dynamic_audio_mix", "evidence_bundle": "artifacts/audio/bus-fades.json", "native_audition": "OPEN", "boundary_note": "No native audition has occurred.", "claim": "AUTOMATED_FADE_ONLY", "transitions": [transition("station", "encounter", "Music"), transition("encounter", "return", "Ambience")]}


class AudioBusFadeTransitionEvidenceTests(unittest.TestCase):
    def test_valid_fade_transitions(self):
        self.assertEqual(validator.validate_record(record()), [])

    def test_gain_and_fade_bounds_are_required(self):
        value = copy.deepcopy(record())
        value["transitions"][0]["from_gain_db"] = 7.0
        value["transitions"][0]["fade_seconds"] = 0
        errors = validator.validate_record(value)
        self.assertIn("transitions[0].from_gain_db must be between -80 and 6 dB", errors)
        self.assertIn("transitions[0].fade_seconds must be greater than 0 and at most 10", errors)

    def test_invalid_bus_and_non_presentation_transition_fail_closed(self):
        value = copy.deepcopy(record())
        value["transitions"][1]["bus"] = "Master"
        value["transitions"][1]["presentation_only"] = False
        errors = validator.validate_record(value)
        self.assertIn("transitions[1].bus is invalid", errors)
        self.assertIn("transitions[1].presentation_only must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(record())
        value["native_audition"] = "PASS"
        errors = validator.validate_record(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
