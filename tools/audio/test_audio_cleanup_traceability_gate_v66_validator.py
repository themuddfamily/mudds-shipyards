"""Focused tests for v66 traceability/gate summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_traceability_gate_v66_validator as validator  # noqa: E402


def summary() -> dict:
    traceability, gate = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "traceability_digest": traceability, "gate_digest": gate, "traceability_id": "traceability-v66", "gate_id": "gate-v66", "canonicalization": "json-sorted-v1", "evidence": evidence, "gate_pass": True}
    return {"schema": "audio_cleanup_traceability_gate_v66", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-traceability-v66", "evidence_bundle": "artifacts/audio/traceability-v66.json", "canonicalization": "json-sorted-v1", "traceability_id": "traceability-v66", "gate_id": "gate-v66", "claim": "AUTOMATED_TRACEABILITY_GATE_ONLY", "boundary_note": "Traceability gating does not establish native audibility.", "record_ids": ["record-a", "record-b"], "traceability_digest": traceability, "gate_digest": gate, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "traceability_gate_pass": True}


class AudioCleanupTraceabilityGateV66Tests(unittest.TestCase):
    def test_valid_traceability_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_gate_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["gate_id"] = "other"
        self.assertIn("records[1].gate_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["traceability_digest"] = "c" * 64
        self.assertIn("records traceability/gate digest pairs must agree", validator.validate_summary(value))

    def test_gate_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["traceability_gate_pass"] = False
        value["records"][0]["gate_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("traceability_gate_pass must be true", errors)
        self.assertIn("records[0].gate_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
