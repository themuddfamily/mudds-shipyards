"""Focused tests for v91 audit/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_audit_state_v91_validator as validator  # noqa: E402


def summary() -> dict:
    audit, state = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "audit_digest": audit, "state_digest": state, "audit_id": "audit-v91", "state_id": "state-v91", "canonicalization": "json-sorted-v1", "evidence": evidence, "state_pass": True}
    return {"schema": "audio_cleanup_audit_state_v91", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-audit-state-v91", "evidence_bundle": "artifacts/audio/audit-state-v91.json", "canonicalization": "json-sorted-v1", "audit_id": "audit-v91", "state_id": "state-v91", "claim": "AUTOMATED_AUDIT_STATE_ONLY", "boundary_note": "Audit state does not establish native audibility.", "record_ids": ["record-a", "record-b"], "audit_digest": audit, "state_digest": state, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "audit_state_pass": True}


class AudioCleanupAuditStateV91Tests(unittest.TestCase):
    def test_valid_audit_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_id"] = "other"
        self.assertIn("records[1].state_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["audit_digest"] = "c" * 64
        self.assertIn("records audit/state digest pairs must agree", validator.validate_summary(value))

    def test_state_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["audit_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("audit_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
