"""Focused tests for landing/cabin stale-callback evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_stale_callback_validator as validator  # noqa: E402


def case(name: str, index: int) -> dict:
    return {"name": name, "old_epoch": index, "current_epoch": index + 1, "callback_sequence": index, "callback_evidence": f"artifacts/audio/{name}-callback.json", "generation_evidence": f"artifacts/audio/{name}-epoch.json", "accepted": False, "sequence_consumed": True, "voice_unchanged": True, "binding_unchanged": True, "presentation_only": True}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_stale_callback_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/stale-callbacks.json", "native_audition": "OPEN", "claim": "AUTOMATED_STALE_CALLBACK_ONLY", "boundary_note": "No native audition has occurred.", "cases": [case(name, index) for index, name in enumerate(sorted(validator.CASES), 1)]}


class AudioLandingCabinStaleCallbackTests(unittest.TestCase):
    def test_complete_stale_callback_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_old_epoch_must_be_rejected_and_sequence_consumed(self):
        value = copy.deepcopy(ledger())
        value["cases"][0]["accepted"] = True
        value["cases"][0]["sequence_consumed"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("cases[0].accepted must be false", errors)
        self.assertIn("cases[0].sequence_consumed must be true", errors)

    def test_epoch_and_voice_guard_evidence_are_required(self):
        value = copy.deepcopy(ledger())
        value["cases"][1]["current_epoch"] = value["cases"][1]["old_epoch"]
        value["cases"][1]["voice_unchanged"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("cases[1].current_epoch must be newer than old_epoch", errors)
        self.assertIn("cases[1].voice_unchanged must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
