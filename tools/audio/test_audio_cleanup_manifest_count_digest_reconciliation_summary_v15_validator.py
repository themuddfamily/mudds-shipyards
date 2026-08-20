"""Focused tests for v15 cleanup manifest count/digest reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_manifest_count_digest_reconciliation_summary_v15_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["manifest-a", "manifest-b"]
    digest = "c" * 64
    records = [{"record_id": "record-1", "manifest_ids": ids, "manifest_count": 2, "manifest_set_sha256": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/rec-1.json", "reconciled": True}, {"record_id": "record-2", "manifest_ids": ids, "manifest_count": 2, "manifest_set_sha256": digest, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/rec-2.json", "reconciled": True}]
    return {"schema": "audio_cleanup_manifest_count_digest_reconciliation_summary_v15", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-count-digest-v15", "evidence_bundle": "artifacts/audio/count-digest-v15.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_MANIFEST_COUNT_DIGEST_ONLY", "boundary_note": "Count/digest reconciliation does not establish native audibility.", "manifest_ids": ids, "manifest_count": 2, "manifest_set_sha256": digest, "records": records, "reconciliation_pass": True}


class AudioCleanupManifestCountDigestV15Tests(unittest.TestCase):
    def test_valid_count_digest_reconciliation(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_count_and_digest_must_reconcile(self):
        value = copy.deepcopy(summary())
        value["manifest_count"] = 3
        value["records"][1]["manifest_set_sha256"] = "d" * 64
        errors = validator.validate_summary(value)
        self.assertIn("manifest_count must match manifest_ids length", errors)
        self.assertIn("records manifest_set_sha256 values must agree", errors)

    def test_roster_and_canonicalization_must_match_records(self):
        value = copy.deepcopy(summary())
        value["records"][0]["manifest_ids"] = ["manifest-a"]
        value["records"][1]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[0].manifest_ids must match ordered summary roster", errors)
        self.assertIn("records[1].canonicalization must match summary canonicalization", errors)

    def test_reconciliation_flag_is_required(self):
        value = copy.deepcopy(summary())
        value["reconciliation_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("reconciliation_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
