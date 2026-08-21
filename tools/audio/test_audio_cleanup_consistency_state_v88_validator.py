"""Focused tests for v88 consistency/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_consistency_state_v88_validator as validator  # noqa: E402


def summary() -> dict:
    consistency, state = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "consistency_digest": consistency, "state_digest": state, "consistency_id": "consistency-v88", "state_id": "state-v88", "canonicalization": "json-sorted-v1", "evidence": evidence, "state_pass": True}
    return {"schema": "audio_cleanup_consistency_state_v88", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-consistency-state-v88", "evidence_bundle": "artifacts/audio/consistency-state-v88.json", "canonicalization": "json-sorted-v1", "consistency_id": "consistency-v88", "state_id": "state-v88", "claim": "AUTOMATED_CONSISTENCY_STATE_ONLY", "boundary_note": "Consistency state does not establish native audibility.", "record_ids": ["record-a", "record-b"], "consistency_digest": consistency, "state_digest": state, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "consistency_state_pass": True}


class AudioCleanupConsistencyStateV88Tests(unittest.TestCase):
    def test_valid_consistency_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_id"] = "other"
        self.assertIn("records[1].state_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["consistency_digest"] = "c" * 64
        self.assertIn("records consistency/state digest pairs must agree", validator.validate_summary(value))

    def test_state_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["consistency_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("consistency_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
