"""Focused tests for landing/cabin stale-binding cleanup evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_stale_binding_cleanup_validator as validator  # noqa: E402


def case(name: str, index: int) -> dict:
    return {"name": name, "old_binding_generation": index, "new_binding_generation": index + 1, "binding_cleanup_evidence": f"artifacts/audio/{name}-binding-cleanup.json", "stale_callback_evidence": f"artifacts/audio/{name}-stale-binding.json", "binding_invalidated": True, "detached": True, "stale_callback_rejected": True, "stale_callback_result": False, "voices_zero": True, "presentation_only": True}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_stale_binding_cleanup_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/stale-binding-cleanup.json", "native_audition": "OPEN", "claim": "AUTOMATED_BINDING_CLEANUP_ONLY", "boundary_note": "No native audition has occurred.", "cases": [case(name, index) for index, name in enumerate(sorted(validator.CASES), 1)]}


class AudioLandingCabinStaleBindingCleanupTests(unittest.TestCase):
    def test_complete_stale_binding_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_binding_generation_must_advance(self):
        value = copy.deepcopy(ledger())
        value["cases"][0]["new_binding_generation"] = value["cases"][0]["old_binding_generation"]
        errors = validator.validate_ledger(value)
        self.assertIn("cases[0].new_binding_generation must be newer than old_binding_generation", errors)

    def test_invalidation_and_detach_flags_are_required(self):
        value = copy.deepcopy(ledger())
        value["cases"][1]["binding_invalidated"] = False
        value["cases"][1]["detached"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("cases[1].binding_invalidated must be true", errors)
        self.assertIn("cases[1].detached must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
