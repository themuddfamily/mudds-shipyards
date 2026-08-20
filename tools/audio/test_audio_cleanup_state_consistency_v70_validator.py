"""Focused tests for v70 state/consistency summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_state_consistency_v70_validator as validator  # noqa: E402


def summary() -> dict:
    state, consistency = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "state_digest": state, "consistency_digest": consistency, "state_id": "state-v70", "consistency_id": "consistency-v70", "canonicalization": "json-sorted-v1", "evidence": evidence, "consistency_pass": True}
    return {"schema": "audio_cleanup_state_consistency_v70", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-state-v70", "evidence_bundle": "artifacts/audio/state-v70.json", "canonicalization": "json-sorted-v1", "state_id": "state-v70", "consistency_id": "consistency-v70", "claim": "AUTOMATED_STATE_CONSISTENCY_ONLY", "boundary_note": "State consistency does not establish native audibility.", "record_ids": ["record-a", "record-b"], "state_digest": state, "consistency_digest": consistency, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "state_consistency_pass": True}


class AudioCleanupStateConsistencyV70Tests(unittest.TestCase):
    def test_valid_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_consistency_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["consistency_id"] = "other"
        self.assertIn("records[1].consistency_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_digest"] = "c" * 64
        self.assertIn("records state/consistency digest pairs must agree", validator.validate_summary(value))

    def test_consistency_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["state_consistency_pass"] = False
        value["records"][0]["consistency_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("state_consistency_pass must be true", errors)
        self.assertIn("records[0].consistency_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
