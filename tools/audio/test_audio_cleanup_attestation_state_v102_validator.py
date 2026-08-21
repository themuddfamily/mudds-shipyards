"""Focused tests for v102 audio cleanup attestation/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_attestation_state_v102_validator as validator  # noqa: E402


def summary() -> dict:
    attestation, state_digest = "a" * 64, "b" * 64

    def record(record_id: str, artifact: str) -> dict:
        return {
            "record_id": record_id, "attestation_digest": attestation,
            "state_digest": state_digest, "attestation_id": "attestation-v102",
            "state_model": "cleanup-state-v1", "state": "closed",
            "attestation": artifact, "state_pass": True,
        }

    return {
        "schema": "audio_cleanup_attestation_state_v102", "revision": "a" * 40,
        "owner": "audio-attestation-owner", "summary_id": "cleanup-attestation-state-v102",
        "attestation_bundle": "artifacts/audio/attestation-state-v102.json",
        "attestation_id": "attestation-v102", "state_model": "cleanup-state-v1",
        "state": "closed", "claim": "AUTOMATED_ATTESTATION_STATE_ONLY",
        "boundary_note": "Attestation state does not establish native audibility.",
        "record_ids": ["record-a", "record-b"], "attestation_digest": attestation,
        "state_digest": state_digest, "records": [
            record("record-a", "artifacts/audio/a.json"),
            record("record-b", "artifacts/audio/b.json"),
        ], "attestation_state_pass": True,
    }


class AudioCleanupAttestationStateV102Tests(unittest.TestCase):
    def test_valid_attestation_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state"] = "ready"
        self.assertIn("records[1].state must match summary", validator.validate_summary(value))

    def test_digest_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["state_digest"] = "c" * 64
        self.assertIn("records[0].state_digest must match summary", validator.validate_summary(value))

    def test_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["attestation_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("attestation_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
