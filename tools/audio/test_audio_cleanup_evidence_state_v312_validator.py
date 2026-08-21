"""Focused tests for v312 audio cleanup evidence/state summaries."""
import copy, sys, unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_state_v312_validator as validator  # noqa: E402

def summary() -> dict:
    evidence_digest, state_digest = "a" * 64, "b" * 64
    def record(record_id: str, evidence: str) -> dict:
        return {"record_id": record_id, "evidence_digest": evidence_digest, "state_digest": state_digest, "evidence_id": "evidence-v312", "state_model": "cleanup-state-v1", "state": "closed", "evidence": evidence, "state_pass": True}
    return {"schema": "audio_cleanup_evidence_state_v312", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-evidence-state-v312", "evidence_bundle": "artifacts/audio/evidence-state-v312.json", "evidence_id": "evidence-v312", "state_model": "cleanup-state-v1", "state": "closed", "claim": "AUTOMATED_EVIDENCE_STATE_ONLY", "detached_status": "NOT_RUN", "native_status": "NOT_RUN", "hardware_status": "NOT_RUN", "human_review_status": "NOT_RUN", "boundary_note": "Automated evidence does not establish detached, native, hardware, or human-review outcomes.", "evidence_digest": evidence_digest, "state_digest": state_digest, "record_ids": ["record-a", "record-b"], "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "evidence_state_pass": True}

class AudioCleanupEvidenceStateV312Tests(unittest.TestCase):
    def test_valid_evidence_state_summary(self): self.assertEqual(validator.validate_summary(summary()), [])
    def test_all_boundary_statuses_require_not_run(self):
        value = copy.deepcopy(summary())
        for key in validator.BOUNDARY_FIELDS: value[key] = "PASS"
        errors = validator.validate_summary(value)
        for key in validator.BOUNDARY_FIELDS: self.assertIn(f"{key} must be NOT_RUN", errors)
    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary()); value["records"][1]["state"] = "ready"
        self.assertIn("records[1].state must match summary", validator.validate_summary(value))
    def test_pass_flags_are_required(self):
        value = copy.deepcopy(summary()); value["evidence_state_pass"], value["records"][0]["state_pass"] = False, False
        errors = validator.validate_summary(value)
        self.assertIn("evidence_state_pass must be true", errors); self.assertIn("records[0].state_pass must be true", errors)

if __name__ == "__main__": unittest.main()
