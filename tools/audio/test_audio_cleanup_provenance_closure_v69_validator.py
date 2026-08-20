"""Focused tests for v69 provenance/closure summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_provenance_closure_v69_validator as validator  # noqa: E402


def summary() -> dict:
    provenance, closure = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "provenance_digest": provenance, "closure_digest": closure, "provenance_id": "provenance-v69", "closure_id": "closure-v69", "canonicalization": "json-sorted-v1", "evidence": evidence, "closure_pass": True}
    return {"schema": "audio_cleanup_provenance_closure_v69", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-closure-v69", "evidence_bundle": "artifacts/audio/closure-v69.json", "canonicalization": "json-sorted-v1", "provenance_id": "provenance-v69", "closure_id": "closure-v69", "claim": "AUTOMATED_PROVENANCE_CLOSURE_ONLY", "boundary_note": "Provenance closure does not establish native audibility.", "record_ids": ["record-a", "record-b"], "provenance_digest": provenance, "closure_digest": closure, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "provenance_closure_pass": True}


class AudioCleanupProvenanceClosureV69Tests(unittest.TestCase):
    def test_valid_closure_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_closure_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["closure_id"] = "other"
        self.assertIn("records[1].closure_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_digest"] = "c" * 64
        self.assertIn("records provenance/closure digest pairs must agree", validator.validate_summary(value))

    def test_closure_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["provenance_closure_pass"] = False
        value["records"][0]["closure_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("provenance_closure_pass must be true", errors)
        self.assertIn("records[0].closure_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
