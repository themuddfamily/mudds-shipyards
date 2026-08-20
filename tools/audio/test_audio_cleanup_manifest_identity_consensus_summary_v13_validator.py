"""Focused tests for v13 cleanup manifest identity consensus."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_manifest_identity_consensus_summary_v13_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["manifest-a", "manifest-b"]
    manifests = [{"manifest_id": ids[0], "path": "artifacts/audio/a.json", "sha256": "a" * 64, "canonicalization": "json-sorted-v1"}, {"manifest_id": ids[1], "path": "artifacts/audio/b.json", "sha256": "b" * 64, "canonicalization": "json-sorted-v1"}]
    records = [{"record_id": "record-1", "manifest_ids": ids, "manifest_set_sha256": "c" * 64, "evidence": "artifacts/audio/record-1.json", "identity_pass": True}, {"record_id": "record-2", "manifest_ids": ids, "manifest_set_sha256": "c" * 64, "evidence": "artifacts/audio/record-2.json", "identity_pass": True}]
    return {"schema": "audio_cleanup_manifest_identity_consensus_summary_v13", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-identity-v13", "evidence_bundle": "artifacts/audio/identity-v13.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_MANIFEST_IDENTITY_ONLY", "boundary_note": "Manifest identity does not establish native audibility.", "manifest_ids": ids, "manifests": manifests, "records": records, "identity_pass": True}


class AudioCleanupManifestIdentityV13Tests(unittest.TestCase):
    def test_valid_identity_consensus(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_manifest_ids_must_match_entries(self):
        value = copy.deepcopy(summary())
        value["manifests"][1]["manifest_id"] = "manifest-c"
        errors = validator.validate_summary(value)
        self.assertIn("manifests[1].manifest_id must be in manifest_ids", errors)
        self.assertIn("manifest_ids must exactly match manifest entries", errors)

    def test_records_must_match_ordered_roster(self):
        value = copy.deepcopy(summary())
        value["records"][1]["manifest_ids"] = ["manifest-b", "manifest-a"]
        errors = validator.validate_summary(value)
        self.assertIn("records[1].manifest_ids must match ordered summary roster", errors)

    def test_canonicalization_and_identity_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["manifests"][0]["canonicalization"] = "other"
        value["records"][0]["identity_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("manifests[0].canonicalization must match summary canonicalization", errors)
        self.assertIn("records[0].identity_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
