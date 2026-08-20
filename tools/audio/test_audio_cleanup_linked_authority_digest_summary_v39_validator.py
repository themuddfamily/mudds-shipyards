"""Focused tests for v39 linked-authority digest summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_linked_authority_digest_summary_v39_validator as validator  # noqa: E402


def summary() -> dict:
    authority, link = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": authority, "link_digest": link, "authority_id": "authority-v39", "authority_link_id": "link-v39", "canonicalization": "json-sorted-v1", "evidence": evidence, "authority_link_pass": True}
    return {"schema": "audio_cleanup_linked_authority_digest_summary_v39", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-linked-authority-v39", "evidence_bundle": "artifacts/audio/linked-authority-v39.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v39", "authority_link_id": "link-v39", "claim": "AUTOMATED_LINKED_AUTHORITY_DIGEST_ONLY", "boundary_note": "Authority links do not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": authority, "link_digest": link, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "linked_authority_pass": True}


class AudioCleanupLinkedAuthorityDigestV39Tests(unittest.TestCase):
    def test_valid_linked_authority_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_authority_link_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_link_id"] = "other"
        self.assertIn("records[1].authority_link_id must match summary", validator.validate_summary(value))

    def test_linked_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["link_digest"] = "c" * 64
        self.assertIn("records linked authority digest pairs must agree", validator.validate_summary(value))

    def test_link_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["linked_authority_pass"] = False
        value["records"][0]["authority_link_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("linked_authority_pass must be true", errors)
        self.assertIn("records[0].authority_link_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
