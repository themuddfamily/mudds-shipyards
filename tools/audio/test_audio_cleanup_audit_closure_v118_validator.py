"""Focused tests for v118 audio cleanup audit/closure summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_audit_closure_v118_validator as validator  # noqa: E402


def summary() -> dict:
    audit, closure = "a" * 64, "b" * 64

    def record(record_id: str, artifact: str, close: str) -> dict:
        return {"record_id": record_id, "audit_digest": audit, "closure_digest": closure,
                "audit_id": "audit-v118", "closure_id": "closure-v118", "audit": artifact,
                "closure": close, "closure_pass": True}

    return {"schema": "audio_cleanup_audit_closure_v118", "revision": "a" * 40,
            "owner": "audio-audit-owner", "summary_id": "cleanup-audit-closure-v118",
            "audit_bundle": "artifacts/audio/audit-closure-v118.json", "audit_id": "audit-v118",
            "closure_id": "closure-v118", "claim": "AUTOMATED_AUDIT_CLOSURE_ONLY",
            "native_status": "NOT_RUN", "stale_callback_status": "NOT_RUN",
            "boundary_note": "Audit closure does not establish native audibility.",
            "audit_digest": audit, "closure_digest": closure,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "artifacts/audio/a.json", "artifacts/audio/a.close.json"),
                record("record-b", "artifacts/audio/b.json", "artifacts/audio/b.close.json")],
            "audit_closure_pass": True}


class AudioCleanupAuditClosureV118Tests(unittest.TestCase):
    def test_valid_audit_closure_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_not_run_semantics_are_required(self):
        value = copy.deepcopy(summary())
        value["native_status"] = "PASS"
        value["stale_callback_status"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_status must be NOT_RUN", errors)
        self.assertIn("stale_callback_status must be NOT_RUN", errors)

    def test_closure_digest_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["closure_digest"] = "c" * 64
        self.assertIn("records[0].closure_digest must match summary", validator.validate_summary(value))

    def test_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["audit_closure_pass"] = False
        value["records"][0]["closure_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("audit_closure_pass must be true", errors)
        self.assertIn("records[0].closure_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
