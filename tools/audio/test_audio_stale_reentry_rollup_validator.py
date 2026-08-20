"""Focused tests for audio stale-callback/re-entry rollup."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_stale_reentry_rollup_validator as validator  # noqa: E402


def component(name: str, index: int) -> dict:
    return {"name": name, "detach_generation": index, "reentry_generation": index + 1, "stale_callback_evidence": f"artifacts/audio/{name}-stale.json", "reentry_evidence": f"artifacts/audio/{name}-reentry.json", "stale_callback_rejected": True, "stale_callback_result": False, "old_voice_stopped": True, "reentry_signal_once": True, "new_voice_started": True}


def rollup() -> dict:
    return {"schema": "audio_stale_reentry_rollup_v1", "revision": "a" * 40, "owner": "audio-lifecycle-owner", "evidence_bundle": "artifacts/audio/stale-reentry-rollup.json", "native_audition": "OPEN", "claim": "AUTOMATED_REENTRY_ONLY", "boundary_note": "No native audition is inferred from lifecycle checks.", "components": [component(name, index) for index, name in enumerate(sorted(validator.REQUIRED_COMPONENTS), 1)]}


class AudioStaleReentryRollupTests(unittest.TestCase):
    def test_complete_rollup(self):
        self.assertEqual(validator.validate_rollup(rollup()), [])

    def test_generation_must_advance(self):
        value = copy.deepcopy(rollup())
        value["components"][0]["reentry_generation"] = value["components"][0]["detach_generation"]
        errors = validator.validate_rollup(value)
        self.assertIn("components[0].reentry_generation must be newer than detach_generation", errors)

    def test_stale_callback_must_be_rejected_and_false(self):
        value = copy.deepcopy(rollup())
        value["components"][1]["stale_callback_rejected"] = False
        value["components"][1]["stale_callback_result"] = True
        errors = validator.validate_rollup(value)
        self.assertIn("components[1].stale_callback_rejected must be true", errors)
        self.assertIn("components[1].stale_callback_result must be false", errors)

    def test_native_audition_remains_open(self):
        value = copy.deepcopy(rollup())
        value["native_audition"] = "PASS"
        errors = validator.validate_rollup(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
