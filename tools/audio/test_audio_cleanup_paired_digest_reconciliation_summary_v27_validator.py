"""Focused tests for v27 paired-digest cleanup reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_paired_digest_reconciliation_summary_v27_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["record-a", "record-b"]
    summary_digest = "a" * 64
    reconciliation_digest = "b" * 64
    records = [{"record_id": ids[0], "summary_digest": summary_digest, "reconciliation_digest": reconciliation_digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/a.json", "pair_pass": True}, {"record_id": ids[1], "summary_digest": summary_digest, "reconciliation_digest": reconciliation_digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/b.json", "pair_pass": True}]
    return {"schema": "audio_cleanup_paired_digest_reconciliation_summary_v27", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-pair-v27", "evidence_bundle": "artifacts/audio/pair-v27.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_PAIRED_DIGEST_ONLY", "boundary_note": "Paired digest reconciliation does not establish native audibility.", "record_ids": ids, "agreed_summary_digest": summary_digest, "agreed_reconciliation_digest": reconciliation_digest, "records": records, "paired_reconciliation_pass": True}


class AudioCleanupPairedDigestV27Tests(unittest.TestCase):
    def test_valid_paired_digest_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_digest_pairs_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["reconciliation_digest"] = "c" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records digest pairs must agree", errors)

    def test_record_roster_and_canonicalization_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["record_id"] = "record-c"
        value["records"][0]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[1].record_id must be in record_ids", errors)
        self.assertIn("records[0].canonicalization must match summary canonicalization", errors)

    def test_pair_pass_flag_is_required(self):
        value = copy.deepcopy(summary())
        value["paired_reconciliation_pass"] = False
        value["records"][0]["pair_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("paired_reconciliation_pass must be true", errors)
        self.assertIn("records[0].pair_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
