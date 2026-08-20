"""Focused tests for v30 paired cleanup root/authority summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_paired_root_authority_summary_v30_validator as validator  # noqa: E402


def summary() -> dict:
    digest_a, digest_b, authority_digest = "a" * 64, "b" * 64, "c" * 64
    def record(record_id: str, evidence: str) -> dict:
        return {"record_id": record_id, "summary_digest": digest_a, "reconciliation_digest": digest_b, "root_id": "record-a", "authority_id": "authority-v30", "authority_digest": authority_digest, "canonicalization": "json-sorted-v1", "evidence": evidence, "authority_pass": True}
    return {"schema": "audio_cleanup_paired_root_authority_summary_v30", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-authority-v30", "evidence_bundle": "artifacts/audio/authority-v30.json", "canonicalization": "json-sorted-v1", "root_id": "record-a", "authority_id": "authority-v30", "claim": "AUTOMATED_PAIRED_ROOT_AUTHORITY_ONLY", "boundary_note": "Authority binding does not establish native audibility.", "record_ids": ["record-a", "record-b"], "root_summary_digest": digest_a, "root_reconciliation_digest": digest_b, "authority_digest": authority_digest, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "paired_authority_pass": True}


class AudioCleanupPairedRootAuthorityV30Tests(unittest.TestCase):
    def test_valid_authority_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_authority_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_digest"] = "d" * 64
        self.assertIn("records[1].authority_digest must match summary authority_digest", validator.validate_summary(value))

    def test_root_and_roster_are_reconciled(self):
        value = copy.deepcopy(summary())
        value["root_id"] = "record-z"
        value["record_ids"] = ["record-a"]
        errors = validator.validate_summary(value)
        self.assertIn("root_id must reference a record", errors)
        self.assertIn("record_ids must exactly match records", errors)

    def test_authority_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["paired_authority_pass"] = False
        value["records"][0]["authority_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("paired_authority_pass must be true", errors)
        self.assertIn("records[0].authority_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
