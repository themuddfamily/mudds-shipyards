"""Focused tests for cleanup stale-generation sequence evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_cleanup_stale_generation_validator as validator  # noqa: E402


def case(name: str, index: int) -> dict:
    return {"name": name, "stale_generation": index, "active_generation": index + 1, "callback_sequence": index, "cleanup_sequence": index + 1, "sequence_evidence": f"artifacts/audio/{name}-sequence.json", "generation_evidence": f"artifacts/audio/{name}-generation.json", "callback_rejected": True, "callback_result": False, "cleanup_committed": True, "voice_state_unchanged": True, "presentation_only": True}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_cleanup_stale_generation_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/stale-generation-sequences.json", "native_audition": "OPEN", "claim": "AUTOMATED_STALE_GENERATION_ONLY", "boundary_note": "No native audition has occurred.", "cases": [case(name, index) for index, name in enumerate(sorted(validator.CASES), 1)]}


class AudioLandingCabinCleanupStaleGenerationTests(unittest.TestCase):
    def test_complete_stale_generation_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_active_generation_and_cleanup_sequence_must_advance(self):
        value = copy.deepcopy(ledger())
        value["cases"][0]["active_generation"] = value["cases"][0]["stale_generation"]
        value["cases"][0]["cleanup_sequence"] = value["cases"][0]["callback_sequence"]
        errors = validator.validate_ledger(value)
        self.assertIn("cases[0].active_generation must be newer than stale_generation", errors)
        self.assertIn("cases[0].cleanup_sequence must be newer than callback_sequence", errors)

    def test_callback_rejection_and_voice_stability_are_required(self):
        value = copy.deepcopy(ledger())
        value["cases"][1]["callback_rejected"] = False
        value["cases"][1]["voice_state_unchanged"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("cases[1].callback_rejected must be true", errors)
        self.assertIn("cases[1].voice_state_unchanged must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
