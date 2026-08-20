"""Focused tests for v72 verification/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_verification_state_v72_validator as validator  # noqa: E402


def summary() -> dict:
    verification, state = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "verification_digest": verification, "state_digest": state, "verification_id": "verification-v72", "state_id": "state-v72", "canonicalization": "json-sorted-v1", "evidence": evidence, "state_pass": True}
    return {"schema": "audio_cleanup_verification_state_v72", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-state-v72", "evidence_bundle": "artifacts/audio/state-v72.json", "canonicalization": "json-sorted-v1", "verification_id": "verification-v72", "state_id": "state-v72", "claim": "AUTOMATED_VERIFICATION_STATE_ONLY", "boundary_note": "Verification state does not establish native audibility.", "record_ids": ["record-a", "record-b"], "verification_digest": verification, "state_digest": state, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "verification_state_pass": True}


class AudioCleanupVerificationStateV72Tests(unittest.TestCase):
    def test_valid_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_id"] = "other"
        self.assertIn("records[1].state_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["verification_digest"] = "c" * 64
        self.assertIn("records verification/state digest pairs must agree", validator.validate_summary(value))

    def test_state_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["verification_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("verification_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
