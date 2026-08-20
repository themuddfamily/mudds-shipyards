"""Focused tests for v24 cleanup identity reconciliation digests."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_identity_reconciliation_digest_summary_v24_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["identity-a", "identity-b"]
    digest = "a" * 64
    records = [{"record_id": "record-1", "identity_ids": ids, "identity_digest": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/id-1.json", "reconciled": True}, {"record_id": "record-2", "identity_ids": ids, "identity_digest": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/id-2.json", "reconciled": True}]
    return {"schema": "audio_cleanup_identity_reconciliation_digest_summary_v24", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-identity-v24", "evidence_bundle": "artifacts/audio/id-v24.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_IDENTITY_RECONCILIATION_DIGEST_ONLY", "boundary_note": "Identity reconciliation does not establish native audibility.", "identity_ids": ids, "identity_digest": digest, "records": records, "reconciliation_pass": True}


class AudioCleanupIdentityV24Tests(unittest.TestCase):
    def test_valid_identity_reconciliation_digest(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_identity_digests_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["identity_digest"] = "b" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records identity_digest values must agree", errors)

    def test_identity_roster_and_canonicalization_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["identity_ids"] = ["identity-a"]
        value["records"][1]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[0].identity_ids must match ordered summary roster", errors)
        self.assertIn("records[1].canonicalization must match summary canonicalization", errors)

    def test_reconciliation_flag_is_required(self):
        value = copy.deepcopy(summary())
        value["reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
