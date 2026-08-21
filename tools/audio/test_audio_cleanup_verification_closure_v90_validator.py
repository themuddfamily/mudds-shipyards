"""Focused tests for v90 verification/closure summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_verification_closure_v90_validator as validator  # noqa: E402


def summary() -> dict:
    verification, closure = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "verification_digest": verification, "closure_digest": closure, "verification_id": "verification-v90", "closure_id": "closure-v90", "canonicalization": "json-sorted-v1", "evidence": evidence, "closure_pass": True}
    return {"schema": "audio_cleanup_verification_closure_v90", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-verification-closure-v90", "evidence_bundle": "artifacts/audio/verification-closure-v90.json", "canonicalization": "json-sorted-v1", "verification_id": "verification-v90", "closure_id": "closure-v90", "claim": "AUTOMATED_VERIFICATION_CLOSURE_ONLY", "boundary_note": "Verification closure does not establish native audibility.", "record_ids": ["record-a", "record-b"], "verification_digest": verification, "closure_digest": closure, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "verification_closure_pass": True}


class AudioCleanupVerificationClosureV90Tests(unittest.TestCase):
    def test_valid_verification_closure_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_closure_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["closure_id"] = "other"
        self.assertIn("records[1].closure_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["verification_digest"] = "c" * 64
        self.assertIn("records verification/closure digest pairs must agree", validator.validate_summary(value))

    def test_closure_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["verification_closure_pass"] = False
        value["records"][0]["closure_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("verification_closure_pass must be true", errors)
        self.assertIn("records[0].closure_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
