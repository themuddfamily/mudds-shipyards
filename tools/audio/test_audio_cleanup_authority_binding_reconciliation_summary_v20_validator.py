"""Focused tests for v20 cleanup authority-binding reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_authority_binding_reconciliation_summary_v20_validator as validator  # noqa: E402


def summary() -> dict:
    ids = ["binding-a", "binding-b"]
    digest = "a" * 64
    exclusions = ["gameplay_damage", "gameplay_phase", "reward"]
    records = [{"record_id": "record-1", "binding_ids": ids, "authority_digest": digest, "canonicalization": "json-sorted-v1", "authority_exclusions": exclusions, "evidence": "artifacts/audio/auth-1.json", "reconciled": True}, {"record_id": "record-2", "binding_ids": ids, "authority_digest": digest, "canonicalization": "json-sorted-v1", "authority_exclusions": exclusions, "evidence": "artifacts/audio/auth-2.json", "reconciled": True}]
    return {"schema": "audio_cleanup_authority_binding_reconciliation_summary_v20", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-auth-v20", "evidence_bundle": "artifacts/audio/auth-v20.json", "canonicalization": "json-sorted-v1", "claim": "AUTOMATED_AUTHORITY_RECONCILIATION_ONLY", "boundary_note": "Authority reconciliation does not establish native audibility.", "binding_ids": ids, "authority_digest": digest, "records": records, "reconciliation_pass": True}


class AudioCleanupAuthorityReconciliationV20Tests(unittest.TestCase):
    def test_valid_authority_reconciliation(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_record_authority_digests_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["authority_digest"] = "b" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records authority_digest values must agree", errors)

    def test_binding_roster_and_exclusions_are_required(self):
        value = copy.deepcopy(summary())
        value["records"][0]["binding_ids"] = ["binding-a"]
        value["records"][1]["authority_exclusions"] = ["gameplay_damage"]
        errors = validator.validate_summary(value)
        self.assertIn("records[0].binding_ids must match ordered summary roster", errors)
        self.assertIn("records[1].authority_exclusions must include gameplay_damage, gameplay_phase, and reward", errors)

    def test_reconciliation_flag_and_canonicalization_are_required(self):
        value = copy.deepcopy(summary())
        value["reconciliation_pass"] = False
        value["records"][1]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("reconciliation_pass must be true", errors)
        self.assertIn("records[1].canonicalization must match summary canonicalization", errors)


if __name__ == "__main__":
    unittest.main()
