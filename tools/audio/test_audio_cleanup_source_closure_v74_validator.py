"""Focused tests for v74 source/closure summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_source_closure_v74_validator as validator  # noqa: E402


def summary() -> dict:
    source, closure = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "source_digest": source, "closure_digest": closure, "source_id": "source-v74", "closure_id": "closure-v74", "canonicalization": "json-sorted-v1", "evidence": evidence, "closure_pass": True}
    return {"schema": "audio_cleanup_source_closure_v74", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-closure-v74", "evidence_bundle": "artifacts/audio/source-closure-v74.json", "canonicalization": "json-sorted-v1", "source_id": "source-v74", "closure_id": "closure-v74", "claim": "AUTOMATED_SOURCE_CLOSURE_ONLY", "boundary_note": "Source closure does not establish native audibility.", "record_ids": ["record-a", "record-b"], "source_digest": source, "closure_digest": closure, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_closure_pass": True}


class AudioCleanupSourceClosureV74Tests(unittest.TestCase):
    def test_valid_source_closure_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_closure_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["closure_id"] = "other"
        self.assertIn("records[1].closure_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["source_digest"] = "c" * 64
        self.assertIn("records source/closure digest pairs must agree", validator.validate_summary(value))

    def test_closure_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_closure_pass"] = False
        value["records"][0]["closure_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_closure_pass must be true", errors)
        self.assertIn("records[0].closure_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
