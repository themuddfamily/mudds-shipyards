"""Focused tests for v92 attestation/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_attestation_state_v92_validator as validator  # noqa: E402


def summary() -> dict:
    attestation, state = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "attestation_digest": attestation, "state_digest": state, "attestation_id": "attestation-v92", "state_id": "state-v92", "canonicalization": "json-sorted-v1", "evidence": evidence, "state_pass": True}
    return {"schema": "audio_cleanup_attestation_state_v92", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-attestation-state-v92", "evidence_bundle": "artifacts/audio/attestation-state-v92.json", "canonicalization": "json-sorted-v1", "attestation_id": "attestation-v92", "state_id": "state-v92", "claim": "AUTOMATED_ATTESTATION_STATE_ONLY", "boundary_note": "Attestation state does not establish native audibility.", "record_ids": ["record-a", "record-b"], "attestation_digest": attestation, "state_digest": state, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "attestation_state_pass": True}


class AudioCleanupAttestationStateV92Tests(unittest.TestCase):
    def test_valid_attestation_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_id"] = "other"
        self.assertIn("records[1].state_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["attestation_digest"] = "c" * 64
        self.assertIn("records attestation/state digest pairs must agree", validator.validate_summary(value))

    def test_state_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["attestation_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("attestation_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
