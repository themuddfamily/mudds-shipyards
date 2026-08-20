"""Focused tests for v67 audit/closure summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_audit_closure_v67_validator as validator  # noqa: E402


def summary() -> dict:
    audit, closure = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "audit_digest": audit, "closure_digest": closure, "audit_id": "audit-v67", "closure_id": "closure-v67", "canonicalization": "json-sorted-v1", "evidence": evidence, "closure_pass": True}
    return {"schema": "audio_cleanup_audit_closure_v67", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-audit-v67", "evidence_bundle": "artifacts/audio/audit-v67.json", "canonicalization": "json-sorted-v1", "audit_id": "audit-v67", "closure_id": "closure-v67", "claim": "AUTOMATED_AUDIT_CLOSURE_ONLY", "boundary_note": "Audit closure does not establish native audibility.", "record_ids": ["record-a", "record-b"], "audit_digest": audit, "closure_digest": closure, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "audit_closure_pass": True}


class AudioCleanupAuditClosureV67Tests(unittest.TestCase):
    def test_valid_audit_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_closure_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["closure_id"] = "other"
        self.assertIn("records[1].closure_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["audit_digest"] = "c" * 64
        self.assertIn("records audit/closure digest pairs must agree", validator.validate_summary(value))

    def test_closure_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["audit_closure_pass"] = False
        value["records"][0]["closure_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("audit_closure_pass must be true", errors)
        self.assertIn("records[0].closure_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
