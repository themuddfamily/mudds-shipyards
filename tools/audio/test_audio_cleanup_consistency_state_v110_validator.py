"""Focused tests for v110 audio cleanup consistency/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_consistency_state_v110_validator as validator  # noqa: E402


def summary() -> dict:
    consistency, state_digest = "a" * 64, "b" * 64

    def record(record_id: str, artifact: str) -> dict:
        return {"record_id": record_id, "consistency_digest": consistency,
                "state_digest": state_digest, "consistency_id": "consistency-v110",
                "state_model": "cleanup-state-v1", "state": "closed",
                "consistency": artifact, "consistency_pass": True}

    return {"schema": "audio_cleanup_consistency_state_v110", "revision": "a" * 40,
            "owner": "audio-consistency-owner", "summary_id": "cleanup-consistency-state-v110",
            "consistency_bundle": "artifacts/audio/consistency-state-v110.json",
            "consistency_id": "consistency-v110", "state_model": "cleanup-state-v1",
            "state": "closed", "claim": "AUTOMATED_CONSISTENCY_STATE_ONLY",
            "boundary_note": "Consistency state does not establish native audibility.",
            "consistency_digest": consistency, "state_digest": state_digest,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")],
            "consistency_state_pass": True}


class AudioCleanupConsistencyStateV110Tests(unittest.TestCase):
    def test_valid_consistency_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state"] = "ready"
        self.assertIn("records[1].state must match summary", validator.validate_summary(value))

    def test_consistency_digest_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["consistency_digest"] = "c" * 64
        self.assertIn("records[0].consistency_digest must match summary", validator.validate_summary(value))

    def test_consistency_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["consistency_state_pass"] = False
        value["records"][0]["consistency_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("consistency_state_pass must be true", errors)
        self.assertIn("records[0].consistency_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
