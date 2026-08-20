"""Focused tests for v18 cleanup completeness/authority summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_manifest_completeness_authority_summary_v18_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["manifest-a", "manifest-b"]
    exclusions = ["gameplay_damage", "gameplay_phase", "reward"]
    entries = [{"manifest_id": ids[0], "sha256": "a" * 64, "canonicalization": "json-sorted-v1", "authority": "presentation_only", "authority_exclusions": exclusions, "evidence": "artifacts/audio/a.json", "complete": True}, {"manifest_id": ids[1], "sha256": "b" * 64, "canonicalization": "json-sorted-v1", "authority": "presentation_only", "authority_exclusions": exclusions, "evidence": "artifacts/audio/b.json", "complete": True}]
    return {"schema": "audio_cleanup_manifest_completeness_authority_summary_v18", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-authority-v18", "evidence_bundle": "artifacts/audio/authority-v18.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_COMPLETENESS_AUTHORITY_ONLY", "boundary_note": "Authority evidence does not establish native audibility.", "manifest_ids": ids, "entries": entries, "completeness_authority_pass": True}


class AudioCleanupAuthorityV18Tests(unittest.TestCase):
    def test_valid_completeness_authority_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_presentation_authority_and_exclusions_are_required(self):
        value = copy.deepcopy(summary())
        value["entries"][0]["authority"] = "gameplay"
        value["entries"][1]["authority_exclusions"] = ["gameplay_damage"]
        errors = validator.validate_summary(value)
        self.assertIn("entries[0].authority must be presentation_only", errors)
        self.assertIn("entries[1].authority_exclusions must include gameplay_damage, gameplay_phase, and reward", errors)

    def test_entries_must_cover_manifest_ids(self):
        value = copy.deepcopy(summary())
        value["entries"] = value["entries"][:1]
        errors = validator.validate_summary(value)
        self.assertIn("entries must exactly cover manifest_ids", errors)

    def test_digest_and_complete_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["entries"][0]["sha256"] = "bad"
        value["entries"][1]["complete"] = False
        errors = validator.validate_summary(value)
        self.assertIn("entries[0].sha256 must be a lowercase 64-character digest", errors)
        self.assertIn("entries[1].complete must be true", errors)


if __name__ == "__main__":
    unittest.main()
