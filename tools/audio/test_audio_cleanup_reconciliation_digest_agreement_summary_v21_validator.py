"""Focused tests for v21 cleanup reconciliation digest agreement."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_reconciliation_digest_agreement_summary_v21_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["record-a", "record-b"]
    digest = "a" * 64
    records = [{"record_id": ids[0], "reconciliation_digest": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/a.json", "agreement_pass": True}, {"record_id": ids[1], "reconciliation_digest": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/b.json", "agreement_pass": True}]
    return {"schema": "audio_cleanup_reconciliation_digest_agreement_summary_v21", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-digest-v21", "evidence_bundle": "artifacts/audio/digest-v21.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_RECONCILIATION_DIGEST_ONLY", "boundary_note": "Digest agreement does not establish native audibility.", "record_ids": ids, "agreed_digest": digest, "records": records, "agreement_pass": True}


class AudioCleanupReconciliationDigestV21Tests(unittest.TestCase):
    def test_valid_digest_agreement(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_reconciliation_digests_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_digest"] = "b" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records reconciliation_digest values must agree", errors)

    def test_record_roster_and_canonicalization_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["record_id"] = "record-c"
        value["records"][0]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[1].record_id must be in record_ids", errors)
        self.assertIn("records[0].canonicalization must match summary canonicalization", errors)

    def test_agreement_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["agreement_pass"] = False
        value["records"][0]["agreement_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("agreement_pass must be true", errors)
        self.assertIn("records[0].agreement_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
