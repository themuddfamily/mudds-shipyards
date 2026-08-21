"""Focused tests for v114 audio cleanup audit/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_audit_state_v114_validator as validator  # noqa: E402


def summary() -> dict:
    audit, state_digest = "a" * 64, "b" * 64

    def record(record_id: str, artifact: str) -> dict:
        return {"record_id": record_id, "audit_digest": audit, "state_digest": state_digest,
                "audit_id": "audit-v114", "state_model": "cleanup-state-v1", "state": "closed",
                "audit": artifact, "audit_pass": True}

    return {"schema": "audio_cleanup_audit_state_v114", "revision": "a" * 40,
            "owner": "audio-audit-owner", "summary_id": "cleanup-audit-state-v114",
            "audit_bundle": "artifacts/audio/audit-state-v114.json", "audit_id": "audit-v114",
            "state_model": "cleanup-state-v1", "state": "closed", "claim": "AUTOMATED_AUDIT_STATE_ONLY",
            "boundary_note": "Audit state does not establish native audibility.",
            "audit_digest": audit, "state_digest": state_digest,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")],
            "audit_state_pass": True}


class AudioCleanupAuditStateV114Tests(unittest.TestCase):
    def test_valid_audit_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state"] = "ready"
        self.assertIn("records[1].state must match summary", validator.validate_summary(value))

    def test_audit_digest_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["audit_digest"] = "c" * 64
        self.assertIn("records[0].audit_digest must match summary", validator.validate_summary(value))

    def test_audit_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["audit_state_pass"] = False
        value["records"][0]["audit_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("audit_state_pass must be true", errors)
        self.assertIn("records[0].audit_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
