"""Focused tests for v31 paired root/authority digest summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_paired_root_authority_digest_summary_v31_validator as validator  # noqa: E402


def summary() -> dict:
    a, b, c, d = "a" * 64, "b" * 64, "c" * 64, "d" * 64
    def record(record_id: str, evidence: str) -> dict:
        return {"record_id": record_id, "summary_digest": a, "reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "root_id": "record-a", "authority_id": "authority-v31", "canonicalization": "json-sorted-v1", "evidence": evidence, "digest_pass": True}
    return {"schema": "audio_cleanup_paired_root_authority_digest_summary_v31", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-authority-digest-v31", "evidence_bundle": "artifacts/audio/authority-digest-v31.json", "canonicalization": "json-sorted-v1", "root_id": "record-a", "authority_id": "authority-v31", "claim": "AUTOMATED_PAIRED_ROOT_AUTHORITY_DIGEST_ONLY", "boundary_note": "Digest binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "root_summary_digest": a, "root_reconciliation_digest": b, "authority_summary_digest": c, "authority_reconciliation_digest": d, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "paired_digest_pass": True}


class AudioCleanupPairedRootAuthorityDigestV31Tests(unittest.TestCase):
    def test_valid_digest_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_authority_digest_pair_is_bound(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_reconciliation_digest"] = "e" * 64
        self.assertIn("records[1].authority_reconciliation_digest must match summary", validator.validate_summary(value))

    def test_cleanup_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_digest"] = "e" * 64
        self.assertIn("records cleanup digest pairs must agree", validator.validate_summary(value))

    def test_digest_pass_flag_is_required(self):
        value = copy.deepcopy(summary())
        value["paired_digest_pass"] = False
        value["records"][0]["digest_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("paired_digest_pass must be true", errors)
        self.assertIn("records[0].digest_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
