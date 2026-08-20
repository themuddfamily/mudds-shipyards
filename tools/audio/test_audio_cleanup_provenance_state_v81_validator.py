"""Focused tests for v81 provenance/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_provenance_state_v81_validator as validator  # noqa: E402


def summary() -> dict:
    provenance, state = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "provenance_digest": provenance, "state_digest": state, "provenance_id": "provenance-v81", "state_id": "state-v81", "canonicalization": "json-sorted-v1", "evidence": evidence, "state_pass": True}
    return {"schema": "audio_cleanup_provenance_state_v81", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-provenance-state-v81", "evidence_bundle": "artifacts/audio/provenance-state-v81.json", "canonicalization": "json-sorted-v1", "provenance_id": "provenance-v81", "state_id": "state-v81", "claim": "AUTOMATED_PROVENANCE_STATE_ONLY", "boundary_note": "Provenance state does not establish native audibility.", "record_ids": ["record-a", "record-b"], "provenance_digest": provenance, "state_digest": state, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "provenance_state_pass": True}


class AudioCleanupProvenanceStateV81Tests(unittest.TestCase):
    def test_valid_provenance_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_id"] = "other"
        self.assertIn("records[1].state_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_digest"] = "c" * 64
        self.assertIn("records provenance/state digest pairs must agree", validator.validate_summary(value))

    def test_state_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["provenance_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("provenance_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
