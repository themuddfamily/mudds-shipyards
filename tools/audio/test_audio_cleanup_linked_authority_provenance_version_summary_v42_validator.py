"""Focused tests for v42 linked authority/provenance/version summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_linked_authority_provenance_version_summary_v42_validator as validator  # noqa: E402


def summary() -> dict:
    authority, provenance = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "provenance_digest": provenance, "authority_id": "authority-v42", "provenance_id": "provenance-v42", "provenance_version": "v42", "canonicalization": "json-sorted-v1", "evidence": evidence, "version_pass": True}
    return {"schema": "audio_cleanup_linked_authority_provenance_version_summary_v42", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-provenance-version-v42", "evidence_bundle": "artifacts/audio/provenance-version-v42.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v42", "provenance_id": "provenance-v42", "provenance_version": "v42", "provenance_versions": ["v41", "v42"], "claim": "AUTOMATED_LINKED_AUTHORITY_PROVENANCE_VERSION_ONLY", "boundary_note": "Version binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "provenance_digest": provenance, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "authority_provenance_version_pass": True}


class AudioCleanupLinkedAuthorityProvenanceVersionV42Tests(unittest.TestCase):
    def test_valid_version_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_version_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_version"] = "v41"
        self.assertIn("records[1].provenance_version must match summary", validator.validate_summary(value))

    def test_version_roster_is_checked(self):
        value = copy.deepcopy(summary())
        value["provenance_versions"] = ["v41"]
        self.assertIn("provenance_version must be in provenance_versions", validator.validate_summary(value))

    def test_version_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["authority_provenance_version_pass"] = False
        value["records"][0]["version_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("authority_provenance_version_pass must be true", errors)
        self.assertIn("records[0].version_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
