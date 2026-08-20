"""Focused tests for v11 root/leaf lineage reconciliation."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_root_leaf_lineage_reconciliation_summary_v11_validator as validator  # noqa: E402


def summary() -> dict:
    root = "a" * 64
    return {"schema": "audio_cleanup_root_leaf_lineage_reconciliation_summary_v11", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-root-leaf-v11", "evidence_bundle": "artifacts/audio/root-leaf-v11.json", "claim": "AUTOMATED_ROOT_LEAF_RECONCILIATION_ONLY", "boundary_note": "Lineage reconciliation does not establish native audibility.", "root_digest": root, "roots": [{"root_id": "root-1", "digest": root, "evidence": "artifacts/audio/root.json"}], "leaves": [{"leaf_id": "leaf-1", "parent_root_id": "root-1", "digest": "b" * 64, "evidence": "artifacts/audio/leaf-1.json", "reconciled": True}, {"leaf_id": "leaf-2", "parent_root_id": "root-1", "digest": "c" * 64, "evidence": "artifacts/audio/leaf-2.json", "reconciled": True}], "reconciliation_pass": True}


class AudioCleanupRootLeafV11Tests(unittest.TestCase):
    def test_valid_root_leaf_reconciliation(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_leaf_parent_must_reference_root(self):
        value = copy.deepcopy(summary())
        value["leaves"][0]["parent_root_id"] = "missing"
        errors = validator.validate_summary(value)
        self.assertIn("leaves[0].parent_root_id must reference the root", errors)

    def test_root_digest_and_leaf_reconciliation_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["roots"][0]["digest"] = "d" * 64
        value["leaves"][1]["reconciled"] = False
        errors = validator.validate_summary(value)
        self.assertIn("roots[0].digest must match root_digest", errors)
        self.assertIn("leaves[1].reconciled must be true", errors)

    def test_unique_root_and_leaf_ids_are_required(self):
        value = copy.deepcopy(summary())
        value["leaves"][1]["leaf_id"] = value["leaves"][0]["leaf_id"]
        errors = validator.validate_summary(value)
        self.assertIn("leaves[1].leaf_id is duplicated", errors)


if __name__ == "__main__":
    unittest.main()
