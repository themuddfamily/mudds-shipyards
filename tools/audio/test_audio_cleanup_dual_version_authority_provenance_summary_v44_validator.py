"""Focused tests for v44 dual-version authority/provenance summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_dual_version_authority_provenance_summary_v44_validator as validator  # noqa: E402


def summary() -> dict:
    authority, provenance = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "provenance_digest": provenance, "authority_id": "authority-v44", "provenance_id": "provenance-v44", "authority_version": "a44", "provenance_version": "p44", "canonicalization": "json-sorted-v1", "evidence": evidence, "dual_version_pass": True}
    return {"schema": "audio_cleanup_dual_version_authority_provenance_summary_v44", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-dual-v44", "evidence_bundle": "artifacts/audio/dual-v44.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v44", "provenance_id": "provenance-v44", "authority_version": "a44", "provenance_version": "p44", "authority_versions": ["a43", "a44"], "provenance_versions": ["p43", "p44"], "claim": "AUTOMATED_DUAL_VERSION_AUTHORITY_PROVENANCE_ONLY", "boundary_note": "Dual-version binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "provenance_digest": provenance, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "dual_version_pass": True}


class AudioCleanupDualVersionAuthorityProvenanceV44Tests(unittest.TestCase):
    def test_valid_dual_version_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_dual_version_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_version"] = "p43"
        self.assertIn("records[1].provenance_version must match summary", validator.validate_summary(value))

    def test_version_rosters_are_checked(self):
        value = copy.deepcopy(summary())
        value["authority_versions"] = ["a43"]
        self.assertIn("authority_version must be in authority_versions", validator.validate_summary(value))

    def test_dual_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["dual_version_pass"] = False
        value["records"][0]["dual_version_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("dual_version_pass must be true", errors)
        self.assertIn("records[0].dual_version_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
