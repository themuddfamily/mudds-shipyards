"""Focused tests for landing/cabin cleanup-generation evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_cleanup_generation_validator as validator  # noqa: E402


def case(name: str, index: int) -> dict:
    return {"name": name, "binding_generation": index, "cleanup_generation": index + 1, "callback_generation": index, "cleanup_evidence": f"artifacts/audio/{name}-cleanup.json", "generation_evidence": f"artifacts/audio/{name}-generation.json", "cleanup_committed": True, "old_callback_rejected": True, "voices_zero": True, "presentation_only": True, "callback_result": False}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_cleanup_generation_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/cleanup-generations.json", "native_audition": "OPEN", "claim": "AUTOMATED_CLEANUP_GENERATION_ONLY", "boundary_note": "No native audition has occurred.", "cases": [case(name, index) for index, name in enumerate(sorted(validator.CASES), 1)]}


class AudioLandingCabinCleanupGenerationTests(unittest.TestCase):
    def test_complete_cleanup_generation_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_cleanup_generation_must_advance(self):
        value = copy.deepcopy(ledger())
        value["cases"][0]["cleanup_generation"] = value["cases"][0]["binding_generation"]
        errors = validator.validate_ledger(value)
        self.assertIn("cases[0].cleanup_generation must be newer than binding_generation", errors)

    def test_old_callback_must_match_binding_generation(self):
        value = copy.deepcopy(ledger())
        value["cases"][1]["callback_generation"] = value["cases"][1]["cleanup_generation"]
        errors = validator.validate_ledger(value)
        self.assertIn("cases[1].callback_generation must equal binding_generation for stale evidence", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
