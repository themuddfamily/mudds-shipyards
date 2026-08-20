"""Focused tests for v64 verification/attestation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_verification_attestation_v64_validator as validator  # noqa: E402


def summary() -> dict:
    verification, attestation = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "verification_digest": verification, "attestation_digest": attestation, "verification_id": "verification-v64", "attestation_id": "attestation-v64", "canonicalization": "json-sorted-v1", "evidence": evidence, "verification_pass": True}
    return {"schema": "audio_cleanup_verification_attestation_v64", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-verification-v64", "evidence_bundle": "artifacts/audio/verification-v64.json", "canonicalization": "json-sorted-v1", "verification_id": "verification-v64", "attestation_id": "attestation-v64", "claim": "AUTOMATED_VERIFICATION_ATTESTATION_ONLY", "boundary_note": "Verification does not establish native audibility.", "record_ids": ["record-a", "record-b"], "verification_digest": verification, "attestation_digest": attestation, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "verification_attestation_pass": True}


class AudioCleanupVerificationAttestationV64Tests(unittest.TestCase):
    def test_valid_verification_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_attestation_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["attestation_id"] = "other"
        self.assertIn("records[1].attestation_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["verification_digest"] = "c" * 64
        self.assertIn("records verification/attestation digest pairs must agree", validator.validate_summary(value))

    def test_verification_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["verification_attestation_pass"] = False
        value["records"][0]["verification_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("verification_attestation_pass must be true", errors)
        self.assertIn("records[0].verification_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
