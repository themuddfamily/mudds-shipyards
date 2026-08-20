"""Focused tests for landing/cabin stale-binding generation evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_stale_binding_generation_validator as validator  # noqa: E402


def case(name: str, index: int) -> dict:
    return {"name": name, "previous_generation": index, "active_generation": index + 1, "callback_generation": index, "generation_evidence": f"artifacts/audio/{name}-generation.json", "callback_evidence": f"artifacts/audio/{name}-callback.json", "one_active_binding": True, "old_callback_rejected": True, "new_binding_retained": True, "presentation_only": True, "callback_result": False}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_stale_binding_generation_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/generation-ledger.json", "native_audition": "OPEN", "claim": "AUTOMATED_GENERATION_ONLY", "boundary_note": "No native audition has occurred.", "cases": [case(name, index) for index, name in enumerate(sorted(validator.CASES), 1)]}


class AudioLandingCabinStaleGenerationTests(unittest.TestCase):
    def test_complete_generation_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_active_generation_must_advance_and_callback_be_old(self):
        value = copy.deepcopy(ledger())
        value["cases"][0]["active_generation"] = value["cases"][0]["previous_generation"]
        value["cases"][0]["callback_generation"] = value["cases"][0]["previous_generation"] + 1
        errors = validator.validate_ledger(value)
        self.assertIn("cases[0].active_generation must be newer than previous_generation", errors)
        self.assertIn("cases[0].callback_generation must equal previous_generation for stale evidence", errors)

    def test_binding_guards_are_required(self):
        value = copy.deepcopy(ledger())
        value["cases"][1]["one_active_binding"] = False
        value["cases"][1]["old_callback_rejected"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("cases[1].one_active_binding must be true", errors)
        self.assertIn("cases[1].old_callback_rejected must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
