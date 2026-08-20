"""Focused tests for v25 cleanup identity/digest reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_identity_digest_reconciliation_summary_v25_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["identity-a", "identity-b"]
    entries = [{"identity_id": ids[0], "digest": "a" * 64, "evidence": "artifacts/audio/a.json", "reconciled": True}, {"identity_id": ids[1], "digest": "b" * 64, "evidence": "artifacts/audio/b.json", "reconciled": True}]
    set_digest = "c" * 64
    records = [{"record_id": "record-1", "identity_ids": ids, "identity_set_digest": set_digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/set-1.json", "reconciled": True}, {"record_id": "record-2", "identity_ids": ids, "identity_set_digest": set_digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/set-2.json", "reconciled": True}]
    return {"schema": "audio_cleanup_identity_digest_reconciliation_summary_v25", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-id-digest-v25", "evidence_bundle": "artifacts/audio/id-digest-v25.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_IDENTITY_DIGEST_ONLY", "boundary_note": "Identity digest reconciliation does not establish native audibility.", "identity_ids": ids, "identity_entries": entries, "records": records, "reconciliation_pass": True}


class AudioCleanupIdentityDigestV25Tests(unittest.TestCase):
    def test_valid_identity_digest_reconciliation(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_identity_entries_must_cover_roster(self):
        value = copy.deepcopy(summary())
        value["identity_entries"] = value["identity_entries"][:1]
        errors = validator.validate_summary(value)
        self.assertIn("identity_entries must exactly cover identity_ids", errors)

    def test_record_digest_and_roster_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["identity_set_digest"] = "d" * 64
        value["records"][0]["identity_ids"] = ["identity-a"]
        errors = validator.validate_summary(value)
        self.assertIn("records identity_set_digest values must agree", errors)
        self.assertIn("records[0].identity_ids must match ordered summary roster", errors)

    def test_digest_and_reconciliation_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["identity_entries"][0]["digest"] = "bad"
        value["records"][1]["reconciled"] = False
        errors = validator.validate_summary(value)
        self.assertIn("identity_entries[0].digest must be a lowercase 64-character digest", errors)
        self.assertIn("records[1].reconciled must be true", errors)


if __name__ == "__main__":
    unittest.main()
