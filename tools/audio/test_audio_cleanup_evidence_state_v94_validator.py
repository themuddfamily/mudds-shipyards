"""Focused tests for v94 evidence/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_state_v94_validator as validator  # noqa: E402


def summary() -> dict:
    evidence, state = "a" * 64, "b" * 64
    def record(rid: str, artifact: str) -> dict:
        return {"record_id": rid, "evidence_digest": evidence, "state_digest": state, "evidence_id": "evidence-v94", "state_id": "state-v94", "canonicalization": "json-sorted-v1", "evidence": artifact, "state_pass": True}
    return {"schema": "audio_cleanup_evidence_state_v94", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-evidence-state-v94", "evidence_bundle": "artifacts/audio/evidence-state-v94.json", "canonicalization": "json-sorted-v1", "evidence_id": "evidence-v94", "state_id": "state-v94", "claim": "AUTOMATED_EVIDENCE_STATE_ONLY", "boundary_note": "Evidence state does not establish native audibility.", "record_ids": ["record-a", "record-b"], "evidence_digest": evidence, "state_digest": state, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "evidence_state_pass": True}


class AudioCleanupEvidenceStateV94Tests(unittest.TestCase):
    def test_valid_evidence_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_id"] = "other"
        self.assertIn("records[1].state_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["evidence_digest"] = "c" * 64
        self.assertIn("records evidence/state digest pairs must agree", validator.validate_summary(value))

    def test_state_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["evidence_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("evidence_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
