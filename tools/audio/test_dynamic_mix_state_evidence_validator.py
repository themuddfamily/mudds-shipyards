"""Focused tests for dynamic mix state/evidence validation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import dynamic_mix_state_evidence_validator as validator  # noqa: E402


def state(name: str) -> dict:
    return {"name": name, "evidence": f"artifacts/audio/mix-{name}.json", "bus_gains_db": {bus: 0.0 for bus in validator.REQUIRED_BUSES}}


def manifest() -> dict:
    return {"schema": "dynamic_mix_state_evidence_v1", "revision": "a" * 40, "mix_owner": "dynamic_audio_mix", "evidence_bundle": "artifacts/audio/dynamic-mix.json", "audition_status": "OPEN", "audition_boundary": "No human audition has occurred.", "claim": "AUTOMATED_MIX_ONLY", "states": [state(name) for name in sorted(validator.REQUIRED_STATES)], "transitions": [{"from": "station", "to": "encounter", "trigger": "encounter_started", "evidence": "artifacts/audio/station-encounter.json", "fade_seconds": 0.75, "presentation_only": True}]}


class DynamicMixStateEvidenceTests(unittest.TestCase):
    def test_complete_state_mix_record(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_missing_bus_and_invalid_gain_fail_closed(self):
        value = copy.deepcopy(manifest())
        value["states"][0]["bus_gains_db"].pop("UI")
        value["states"][1]["bus_gains_db"]["Music"] = 7.0
        errors = validator.validate_manifest(value)
        self.assertIn("bus_gains_db missing UI", errors[0] if errors else "")
        self.assertTrue(any("bus_gains_db.Music must be between -80 and 6 dB" in error for error in errors))

    def test_transition_must_be_presentation_only_with_bounded_fade(self):
        value = copy.deepcopy(manifest())
        value["transitions"][0]["presentation_only"] = False
        value["transitions"][0]["fade_seconds"] = 11.0
        errors = validator.validate_manifest(value)
        self.assertIn("transitions[0].fade_seconds must be between 0 and 10", errors)
        self.assertIn("transitions[0].presentation_only must be true", errors)

    def test_human_audition_claim_is_rejected(self):
        value = copy.deepcopy(manifest())
        value["audition_status"] = "PASS"
        errors = validator.validate_manifest(value)
        self.assertIn("audition_status must be OPEN until human audition is recorded", errors)


if __name__ == "__main__":
    unittest.main()
