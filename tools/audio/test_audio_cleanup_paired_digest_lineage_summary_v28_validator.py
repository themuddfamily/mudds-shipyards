"""Focused tests for v28 paired-digest cleanup lineage."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_paired_digest_lineage_summary_v28_validator as validator  # noqa: E402


def summary() -> dict:
    digest_a, digest_b = "a" * 64, "b" * 64
    return {
        "schema": "audio_cleanup_paired_digest_lineage_summary_v28",
        "revision": "a" * 40,
        "owner": "audio-evidence-owner",
        "summary_id": "cleanup-lineage-v28",
        "evidence_bundle": "artifacts/audio/lineage-v28.json",
        "canonicalization": "json-sorted-v1",
        "claim": "AUTOMATED_PAIRED_DIGEST_LINEAGE_ONLY",
        "boundary_note": "Lineage reconciliation does not establish native audibility.",
        "record_ids": ["record-a", "record-b"],
        "root_summary_digest": digest_a,
        "root_reconciliation_digest": digest_b,
        "records": [
            {"record_id": "record-a", "summary_digest": digest_a, "reconciliation_digest": digest_b, "parent_record_id": None, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/a.json", "lineage_pass": True},
            {"record_id": "record-b", "summary_digest": digest_a, "reconciliation_digest": digest_b, "parent_record_id": "record-a", "parent_summary_digest": digest_a, "parent_reconciliation_digest": digest_b, "canonicalization": "json-sorted-v1", "evidence": "artifacts/audio/b.json", "lineage_pass": True},
        ],
        "paired_lineage_pass": True,
    }


class AudioCleanupPairedDigestLineageV28Tests(unittest.TestCase):
    def test_valid_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_parent_pair_must_match(self):
        value = copy.deepcopy(summary())
        value["records"][1]["parent_reconciliation_digest"] = "c" * 64
        self.assertIn("records[1].parent_reconciliation_digest must match parent", validator.validate_summary(value))

    def test_root_and_roster_are_reconciled(self):
        value = copy.deepcopy(summary())
        value["root_summary_digest"] = "c" * 64
        value["record_ids"] = ["record-a"]
        errors = validator.validate_summary(value)
        self.assertIn("root_summary_digest must match first record", errors)
        self.assertIn("record_ids must exactly match records", errors)

    def test_lineage_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["paired_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("paired_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
