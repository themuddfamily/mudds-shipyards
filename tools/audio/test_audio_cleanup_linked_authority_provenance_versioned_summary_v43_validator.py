"""Focused tests for v43 source/versioned linked authority summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_linked_authority_provenance_versioned_summary_v43_validator as validator  # noqa: E402


def summary() -> dict:
    a, b, c = "a" * 64, "b" * 64, "c" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": a, "provenance_digest": b, "version_digest": c, "authority_id": "authority-v43", "provenance_id": "provenance-v43", "provenance_source": "audio-manifest-v43", "provenance_version": "v43", "canonicalization": "json-sorted-v1", "evidence": evidence, "versioned_link_pass": True}
    return {"schema": "audio_cleanup_linked_authority_provenance_versioned_summary_v43", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-versioned-v43", "evidence_bundle": "artifacts/audio/versioned-v43.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v43", "provenance_id": "provenance-v43", "provenance_source": "audio-manifest-v43", "provenance_version": "v43", "provenance_versions": ["v42", "v43"], "claim": "AUTOMATED_LINKED_AUTHORITY_PROVENANCE_VERSIONED_ONLY", "boundary_note": "Versioned provenance does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": a, "provenance_digest": b, "version_digest": c, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "versioned_authority_provenance_pass": True}


class AudioCleanupLinkedAuthorityProvenanceVersionedV43Tests(unittest.TestCase):
    def test_valid_versioned_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_source_version_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["provenance_source"] = "other"
        self.assertIn("records[1].provenance_source must match summary", validator.validate_summary(value))

    def test_digest_triple_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["version_digest"] = "d" * 64
        self.assertIn("records authority/provenance/version digests must agree", validator.validate_summary(value))

    def test_versioned_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["versioned_authority_provenance_pass"] = False
        value["records"][0]["versioned_link_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("versioned_authority_provenance_pass must be true", errors)
        self.assertIn("records[0].versioned_link_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
