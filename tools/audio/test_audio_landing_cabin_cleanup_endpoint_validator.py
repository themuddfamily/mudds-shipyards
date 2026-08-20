"""Focused tests for landing/cabin ambience cleanup endpoint evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_landing_cabin_cleanup_endpoint_validator as validator  # noqa: E402


def endpoint(name: str, index: int) -> dict:
    return {"name": name, "reason": f"event:{name}", "old_generation": index, "new_generation": index + 1, "cleanup_evidence": f"artifacts/audio/{name}-cleanup.json", "generation_evidence": f"artifacts/audio/{name}-generation.json", "voices_zero": True, "binding_cleared": True, "stale_callback_rejected": True, "presentation_only": True}


def ledger() -> dict:
    return {"schema": "audio_landing_cabin_cleanup_endpoint_v1", "revision": "a" * 40, "owner": "landing-cabin-audio-owner", "evidence_bundle": "artifacts/audio/cleanup-endpoints.json", "native_audition": "OPEN", "claim": "AUTOMATED_CLEANUP_ONLY", "boundary_note": "No native audition has occurred.", "endpoints": [endpoint(name, index) for index, name in enumerate(sorted(validator.REQUIRED_ENDPOINTS), 1)]}


class AudioLandingCabinCleanupTests(unittest.TestCase):
    def test_complete_cleanup_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_generation_must_advance(self):
        value = copy.deepcopy(ledger())
        value["endpoints"][0]["new_generation"] = value["endpoints"][0]["old_generation"]
        errors = validator.validate_ledger(value)
        self.assertIn("endpoints[0].new_generation must be newer than old_generation", errors)

    def test_cleanup_flags_must_be_true(self):
        value = copy.deepcopy(ledger())
        value["endpoints"][1]["voices_zero"] = False
        value["endpoints"][1]["stale_callback_rejected"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("endpoints[1].voices_zero must be true", errors)
        self.assertIn("endpoints[1].stale_callback_rejected must be true", errors)

    def test_native_audition_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
