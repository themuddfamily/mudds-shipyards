"""Focused tests for audio teardown/detach lifecycle evidence."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_teardown_lifecycle_evidence_validator as validator  # noqa: E402


def component(name: str) -> dict:
    return {"component": name, "attach_evidence": f"artifacts/audio/{name}-attach.json", "detach_evidence": f"artifacts/audio/{name}-detach.json", "reentry_evidence": f"artifacts/audio/{name}-reentry.json", "detach_stops_voices": True, "detach_clears_transients": True, "stale_callback_rejected": True, "reentry_reconnects_once": True, "notes": "Detach is presentation cleanup and rejects stale generation callbacks."}


def ledger() -> dict:
    return {"schema": "audio_teardown_lifecycle_evidence_v1", "revision": "a" * 40, "lifecycle_owner": "audio-lifecycle-owner", "evidence_bundle": "artifacts/audio/teardown-lifecycle.json", "native_audition": "OPEN", "claim": "AUTOMATED_LIFECYCLE_ONLY", "boundary_note": "Lifecycle evidence does not establish native audibility.", "components": [component(name) for name in sorted(validator.REQUIRED_COMPONENTS)]}


class AudioTeardownLifecycleEvidenceTests(unittest.TestCase):
    def test_complete_lifecycle_ledger(self):
        self.assertEqual(validator.validate_ledger(ledger()), [])

    def test_missing_component_and_reentry_evidence_fail_closed(self):
        value = copy.deepcopy(ledger())
        value["components"] = value["components"][:-1]
        value["components"][0]["reentry_evidence"] = ""
        errors = validator.validate_ledger(value)
        self.assertIn("components[0].reentry_evidence is required", errors)
        self.assertIn("components must cover: station_music", errors)

    def test_cleanup_guards_must_be_true(self):
        value = copy.deepcopy(ledger())
        value["components"][1]["stale_callback_rejected"] = False
        errors = validator.validate_ledger(value)
        self.assertIn("components[1].stale_callback_rejected must be true", errors)

    def test_native_audition_claim_stays_open(self):
        value = copy.deepcopy(ledger())
        value["native_audition"] = "PASS"
        errors = validator.validate_ledger(value)
        self.assertIn("native_audition must be OPEN", errors)


if __name__ == "__main__":
    unittest.main()
