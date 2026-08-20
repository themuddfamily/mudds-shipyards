"""Focused tests for v83 source/state summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_source_state_v83_validator as validator  # noqa: E402


def summary() -> dict:
    source, state = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "source_digest": source, "state_digest": state, "source_id": "source-v83", "state_id": "state-v83", "canonicalization": "json-sorted-v1", "evidence": evidence, "state_pass": True}
    return {"schema": "audio_cleanup_source_state_v83", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-state-v83", "evidence_bundle": "artifacts/audio/source-state-v83.json", "canonicalization": "json-sorted-v1", "source_id": "source-v83", "state_id": "state-v83", "claim": "AUTOMATED_SOURCE_STATE_ONLY", "boundary_note": "Source state does not establish native audibility.", "record_ids": ["record-a", "record-b"], "source_digest": source, "state_digest": state, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_state_pass": True}


class AudioCleanupSourceStateV83Tests(unittest.TestCase):
    def test_valid_source_state_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_state_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["state_id"] = "other"
        self.assertIn("records[1].state_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["source_digest"] = "c" * 64
        self.assertIn("records source/state digest pairs must agree", validator.validate_summary(value))

    def test_state_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_state_pass"] = False
        value["records"][0]["state_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_state_pass must be true", errors)
        self.assertIn("records[0].state_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
