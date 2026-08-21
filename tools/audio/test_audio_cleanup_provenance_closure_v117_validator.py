"""Focused tests for v117 audio cleanup provenance/closure summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_provenance_closure_v117_validator as validator  # noqa: E402


def summary() -> dict:
    provenance, closure = "a" * 64, "b" * 64

    def record(record_id: str, source: str, close: str) -> dict:
        return {"record_id": record_id, "provenance_digest": provenance,
                "closure_digest": closure, "provenance_id": "provenance-v117",
                "closure_id": "closure-v117", "provenance": source,
                "closure": close, "closure_pass": True}

    return {"schema": "audio_cleanup_provenance_closure_v117", "revision": "a" * 40,
            "owner": "audio-provenance-owner", "summary_id": "cleanup-provenance-closure-v117",
            "provenance_bundle": "artifacts/audio/provenance-closure-v117.json",
            "provenance_id": "provenance-v117", "closure_id": "closure-v117",
            "claim": "AUTOMATED_PROVENANCE_CLOSURE_ONLY", "native_status": "NOT_RUN",
            "stale_callback_status": "NOT_RUN",
            "boundary_note": "Provenance closure does not establish native audibility.",
            "provenance_digest": provenance, "closure_digest": closure,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "artifacts/audio/a.json", "artifacts/audio/a.close.json"),
                record("record-b", "artifacts/audio/b.json", "artifacts/audio/b.close.json")],
            "provenance_closure_pass": True}


class AudioCleanupProvenanceClosureV117Tests(unittest.TestCase):
    def test_valid_provenance_closure_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_not_run_semantics_are_required(self):
        value = copy.deepcopy(summary())
        value["native_status"] = "PASS"
        value["stale_callback_status"] = "PASS"
        errors = validator.validate_summary(value)
        self.assertIn("native_status must be NOT_RUN", errors)
        self.assertIn("stale_callback_status must be NOT_RUN", errors)

    def test_closure_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["closure_id"] = "other"
        self.assertIn("records[1].closure_id must match summary", validator.validate_summary(value))

    def test_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["provenance_closure_pass"] = False
        value["records"][0]["closure_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("provenance_closure_pass must be true", errors)
        self.assertIn("records[0].closure_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
