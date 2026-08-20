"""Focused tests for v48 dual-version authority summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_dual_version_authority_summary_v48_validator as validator  # noqa: E402


def summary() -> dict:
    authority_summary, authority = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_summary_digest": authority_summary, "authority_digest": authority, "authority_id": "authority-v48", "authority_version": "a48", "provenance_version": "p48", "canonicalization": "json-sorted-v1", "evidence": evidence, "authority_summary_pass": True}
    return {"schema": "audio_cleanup_dual_version_authority_summary_v48", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-authority-summary-v48", "evidence_bundle": "artifacts/audio/authority-summary-v48.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v48", "authority_version": "a48", "provenance_version": "p48", "authority_versions": ["a47", "a48"], "provenance_versions": ["p47", "p48"], "claim": "AUTOMATED_DUAL_VERSION_AUTHORITY_SUMMARY_ONLY", "boundary_note": "Authority summary does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_summary_digest": authority_summary, "authority_digest": authority, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "dual_authority_summary_pass": True}


class AudioCleanupDualVersionAuthoritySummaryV48Tests(unittest.TestCase):
    def test_valid_authority_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_authority_summary_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_summary_digest"] = "c" * 64
        self.assertIn("records[1].authority_summary_digest must match summary", validator.validate_summary(value))

    def test_authority_version_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["authority_versions"] = ["a47"]
        self.assertIn("authority_version must be in authority_versions", validator.validate_summary(value))

    def test_authority_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["dual_authority_summary_pass"] = False
        value["records"][0]["authority_summary_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("dual_authority_summary_pass must be true", errors)
        self.assertIn("records[0].authority_summary_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
