"""Focused tests for v119 audio cleanup audit/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_audit_state_v119_validator as validator  # noqa: E402


def summary() -> dict:
    audit, state_digest = "a" * 64, "b" * 64

    def record(record_id: str, artifact: str) -> dict:
        return {"record_id": record_id, "audit_digest": audit, "state_digest": state_digest,
                "audit_id": "audit-v119", "state_model": "cleanup-state-v1", "state": "closed",
                "audit": artifact, "state_pass": True}

    return {"schema": "audio_cleanup_audit_state_v119", "revision": "a" * 40,
            "owner": "audio-audit-owner", "summary_id": "cleanup-audit-state-v119",
            "audit_bundle": "artifacts/audio/audit-state-v119.json", "audit_id": "audit-v119",
            "state_model": "cleanup-state-v1", "state": "closed", "claim": "AUTOMATED_AUDIT_STATE_ONLY",
            "native_status": "NOT_RUN", "stale_callback_status": "NOT_RUN",
            "boundary_note": "Audit state does not establish native audibility.",
            "audit_digest": audit, "state_digest": state_digest,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")],
            "audit_state_pass": True}


class AudioCleanupAuditStateV119Tests(unittest.TestCase):
    def test_valid_audit_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_not_run_semantics_are_required(self):
        value = copy.deepcopy(summary())
        value["native_status"] = "PASS"
        value["stale_callback_status"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_status must be NOT_RUN", errors)
        self.assertIn("stale_callback_status must be NOT_RUN", errors)

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state"] = "ready"
        self.assertIn("records[1].state must match summary", validator.validate_summary(value))

    def test_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["audit_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("audit_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
