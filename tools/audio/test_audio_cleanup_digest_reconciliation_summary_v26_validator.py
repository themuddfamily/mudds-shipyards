"""Focused tests for v26 cleanup digest/reconciliation summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_reconciliation_summary_v26_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["record-a", "record-b"]
    summary_digest = "a" * 64
    reconciliation_digest = "b" * 64
    records = [{"record_id": ids[0], "summary_digest": summary_digest, "reconciliation_digest": reconciliation_digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/a.json", "reconciled": True}, {"record_id": ids[1], "summary_digest": summary_digest, "reconciliation_digest": reconciliation_digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/b.json", "reconciled": True}]
    return {"schema": "audio_cleanup_digest_reconciliation_summary_v26", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-digest-v26", "evidence_bundle": "artifacts/audio/digest-v26.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_DIGEST_RECONCILIATION_ONLY", "boundary_note": "Digest reconciliation does not establish native audibility.", "record_ids": ids, "summary_digest": summary_digest, "reconciliation_digest": reconciliation_digest, "records": records, "digest_reconciliation_pass": True}


class AudioCleanupDigestReconciliationV26Tests(unittest.TestCase):
    def test_valid_paired_digest_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_summary_and_reconciliation_digests_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["summary_digest"] = "c" * 64
        value["records"][0]["reconciliation_digest"] = "d" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records summary_digest values must agree", errors)
        self.assertIn("records reconciliation_digest values must agree", errors)

    def test_record_roster_and_canonicalization_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["record_id"] = "record-c"
        value["records"][0]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[1].record_id must be in record_ids", errors)
        self.assertIn("records[0].canonicalization must match summary canonicalization", errors)

    def test_reconciliation_flag_is_required(self):
        value = copy.deepcopy(summary())
        value["digest_reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("digest_reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
