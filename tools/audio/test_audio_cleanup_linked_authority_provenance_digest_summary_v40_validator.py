"""Focused tests for v40 linked authority/provenance digests."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_linked_authority_provenance_digest_summary_v40_validator as validator  # noqa: E402


def summary() -> dict:
    authority, provenance = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "provenance_digest": provenance, "authority_id": "authority-v40", "provenance_id": "provenance-v40", "canonicalization": "json-sorted-v1", "evidence": evidence, "provenance_pass": True}
    return {"schema": "audio_cleanup_linked_authority_provenance_digest_summary_v40", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-provenance-v40", "evidence_bundle": "artifacts/audio/provenance-v40.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v40", "provenance_id": "provenance-v40", "claim": "AUTOMATED_LINKED_AUTHORITY_PROVENANCE_DIGEST_ONLY", "boundary_note": "Provenance binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "provenance_digest": provenance, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "authority_provenance_pass": True}


class AudioCleanupLinkedAuthorityProvenanceV40Tests(unittest.TestCase):
    def test_valid_provenance_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_provenance_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_id"] = "other"
        self.assertIn("records[1].provenance_id must match summary", validator.validate_summary(value))

    def test_provenance_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_digest"] = "c" * 64
        self.assertIn("records authority/provenance digest pairs must agree", validator.validate_summary(value))

    def test_provenance_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["authority_provenance_pass"] = False
        value["records"][0]["provenance_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("authority_provenance_pass must be true", errors)
        self.assertIn("records[0].provenance_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
