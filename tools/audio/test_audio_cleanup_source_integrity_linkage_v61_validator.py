"""Focused tests for v61 source-integrity/linkage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_source_integrity_linkage_v61_validator as validator  # noqa: E402


def summary() -> dict:
    source, linkage = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "source_digest": source, "linkage_digest": linkage, "source_id": "source-v61", "linkage_id": "linkage-v61", "canonicalization": "json-sorted-v1", "evidence": evidence, "integrity_pass": True}
    return {"schema": "audio_cleanup_source_integrity_linkage_v61", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-integrity-v61", "evidence_bundle": "artifacts/audio/integrity-v61.json", "canonicalization": "json-sorted-v1", "source_id": "source-v61", "linkage_id": "linkage-v61", "claim": "AUTOMATED_SOURCE_INTEGRITY_LINKAGE_ONLY", "boundary_note": "Integrity linkage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "source_digest": source, "linkage_digest": linkage, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_integrity_pass": True}


class AudioCleanupSourceIntegrityLinkageV61Tests(unittest.TestCase):
    def test_valid_integrity_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_linkage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["linkage_id"] = "other"
        self.assertIn("records[1].linkage_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["source_digest"] = "c" * 64
        self.assertIn("records source/linkage digest pairs must agree", validator.validate_summary(value))

    def test_integrity_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_integrity_pass"] = False
        value["records"][0]["integrity_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_integrity_pass must be true", errors)
        self.assertIn("records[0].integrity_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
