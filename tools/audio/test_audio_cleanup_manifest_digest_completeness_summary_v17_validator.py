"""Focused tests for v17 cleanup manifest digest completeness."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_manifest_digest_completeness_summary_v17_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["manifest-a", "manifest-b"]
    entries = [{"manifest_id": ids[0], "sha256": "a" * 64, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/a.json", "complete": True}, {"manifest_id": ids[1], "sha256": "b" * 64, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/b.json", "complete": True}]
    return {"schema": "audio_cleanup_manifest_digest_completeness_summary_v17", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-complete-v17", "evidence_bundle": "artifacts/audio/complete-v17.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_MANIFEST_COMPLETENESS_ONLY", "boundary_note": "Completeness does not establish native audibility.", "expected_manifest_ids": ids, "observed_manifest_ids": ids, "entries": entries, "completeness_pass": True}


class AudioCleanupCompletenessV17Tests(unittest.TestCase):
    def test_valid_complete_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_missing_and_unexpected_ids_are_rejected(self):
        value = copy.deepcopy(summary())
        value["observed_manifest_ids"] = ["manifest-a", "manifest-c"]
        errors = validator.validate_summary(value)
        self.assertIn("observed_manifest_ids missing: manifest-b", errors)
        self.assertIn("observed_manifest_ids unexpected: manifest-c", errors)

    def test_entries_must_cover_observed_ids(self):
        value = copy.deepcopy(summary())
        value["entries"] = value["entries"][:1]
        errors = validator.validate_summary(value)
        self.assertIn("entries must exactly cover observed_manifest_ids", errors)

    def test_digest_and_completeness_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["entries"][0]["sha256"] = "bad"
        value["entries"][1]["complete"] = False
        errors = validator.validate_summary(value)
        self.assertIn("entries[0].sha256 must be a lowercase 64-character digest", errors)
        self.assertIn("entries[1].complete must be true", errors)


if __name__ == "__main__":
    unittest.main()
