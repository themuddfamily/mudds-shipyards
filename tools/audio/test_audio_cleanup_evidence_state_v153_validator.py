"""Focused tests for v153 audio cleanup evidence/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_state_v153_validator as validator  # noqa: E402


def summary() -> dict:
    evidence, state_digest = "a" * 64, "b" * 64

    def record(record_id: str, artifact: str) -> dict:
        return {"record_id": record_id, "evidence_digest": evidence, "state_digest": state_digest,
                "evidence_id": "evidence-v153", "state_model": "cleanup-state-v1", "state": "closed",
                "evidence": artifact, "state_pass": True}

    return {"schema": "audio_cleanup_evidence_state_v153", "revision": "a" * 40,
            "owner": "audio-evidence-owner", "summary_id": "cleanup-evidence-state-v153",
            "evidence_bundle": "artifacts/audio/evidence-state-v153.json", "evidence_id": "evidence-v153",
            "state_model": "cleanup-state-v1", "state": "closed", "claim": "AUTOMATED_EVIDENCE_STATE_ONLY",
            "native_status": "NOT_RUN", "stale_callback_status": "NOT_RUN",
            "boundary_note": "Evidence state does not establish native audibility.",
            "evidence_digest": evidence, "state_digest": state_digest,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")],
            "evidence_state_pass": True}


class AudioCleanupEvidenceStateV153Tests(unittest.TestCase):
    def test_valid_evidence_state_summary(self):
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
        value["evidence_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("evidence_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
