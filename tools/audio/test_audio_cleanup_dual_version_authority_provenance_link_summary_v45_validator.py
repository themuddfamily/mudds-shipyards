"""Focused tests for v45 dual-version authority/provenance links."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_dual_version_authority_provenance_link_summary_v45_validator as validator  # noqa: E402


def summary() -> dict:
    a, b, c = "a" * 64, "b" * 64, "c" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "authority_digest": a, "provenance_digest": b, "link_digest": c, "authority_id": "authority-v45", "provenance_id": "provenance-v45", "link_id": "link-v45", "authority_version": "a45", "provenance_version": "p45", "canonicalization": "json-sorted-v1", "evidence": evidence, "link_pass": True}
    return {"schema": "audio_cleanup_dual_version_authority_provenance_link_summary_v45", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-link-v45", "evidence_bundle": "artifacts/audio/link-v45.json", "canonicalization": "json-sorted-v1", "authority_id": "authority-v45", "provenance_id": "provenance-v45", "link_id": "link-v45", "authority_version": "a45", "provenance_version": "p45", "authority_versions": ["a44", "a45"], "provenance_versions": ["p44", "p45"], "claim": "AUTOMATED_DUAL_VERSION_AUTHORITY_PROVENANCE_LINK_ONLY", "boundary_note": "Link binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "authority_digest": a, "provenance_digest": b, "link_digest": c, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "dual_link_pass": True}


class AudioCleanupDualVersionAuthorityProvenanceLinkV45Tests(unittest.TestCase):
    def test_valid_link_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_link_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["link_id"] = "other"
        self.assertIn("records[1].link_id must match summary", validator.validate_summary(value))

    def test_triple_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["link_digest"] = "d" * 64
        self.assertIn("records dual-version authority/provenance/link digests must agree", validator.validate_summary(value))

    def test_link_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["dual_link_pass"] = False
        value["records"][0]["link_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("dual_link_pass must be true", errors)
        self.assertIn("records[0].link_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
