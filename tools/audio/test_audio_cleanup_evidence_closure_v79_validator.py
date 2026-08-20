"""Focused tests for v79 evidence/closure summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_closure_v79_validator as validator  # noqa: E402


def summary() -> dict:
    evidence, closure = "a" * 64, "b" * 64
    def record(rid: str, artifact: str) -> dict:
        return {"record_id": rid, "evidence_digest": evidence, "closure_digest": closure, "evidence_id": "evidence-v79", "closure_id": "closure-v79", "canonicalization": "json-sorted-v1", "evidence": artifact, "closure_pass": True}
    return {"schema": "audio_cleanup_evidence_closure_v79", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-evidence-closure-v79", "evidence_bundle": "artifacts/audio/evidence-closure-v79.json", "canonicalization": "json-sorted-v1", "evidence_id": "evidence-v79", "closure_id": "closure-v79", "claim": "AUTOMATED_EVIDENCE_CLOSURE_ONLY", "boundary_note": "Evidence closure does not establish native audibility.", "record_ids": ["record-a", "record-b"], "evidence_digest": evidence, "closure_digest": closure, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "evidence_closure_pass": True}


class AudioCleanupEvidenceClosureV79Tests(unittest.TestCase):
    def test_valid_evidence_closure_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_closure_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["closure_id"] = "other"
        self.assertIn("records[1].closure_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["evidence_digest"] = "c" * 64
        self.assertIn("records evidence/closure digest pairs must agree", validator.validate_summary(value))

    def test_closure_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["evidence_closure_pass"] = False
        value["records"][0]["closure_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("evidence_closure_pass must be true", errors)
        self.assertIn("records[0].closure_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
