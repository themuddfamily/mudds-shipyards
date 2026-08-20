"""Focused tests for v9 cleanup evidence lineage digest summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_lineage_digest_summary_v9_validator as validator  # noqa: E402


def summary() -> dict:
    root_digest = "a" * 64
    return {"schema": "audio_cleanup_evidence_lineage_digest_summary_v9", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-lineage-v9", "evidence_bundle": "artifacts/audio/lineage-v9.json", "claim": "AUTOMATED_LINEAGE_ONLY", "boundary_note": "Lineage evidence does not establish native audibility.", "root_digest": root_digest, "lineage": [{"node_id": "root", "parent_id": None, "digest": root_digest, "evidence": "artifacts/audio/root.json", "accepted": True}, {"node_id": "child", "parent_id": "root", "digest": "b" * 64, "evidence": "artifacts/audio/child.json", "accepted": True}], "lineage_pass": True}


class AudioCleanupLineageV9Tests(unittest.TestCase):
    def test_valid_root_and_child_lineage(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_parent_reference_must_exist(self):
        value = copy.deepcopy(summary())
        value["lineage"][1]["parent_id"] = "missing"
        errors = validator.validate_summary(value)
        self.assertIn("lineage parent reference missing is missing", errors)

    def test_exactly_one_root_and_root_digest_are_required(self):
        value = copy.deepcopy(summary())
        value["lineage"][1]["parent_id"] = None
        value["root_digest"] = "c" * 64
        errors = validator.validate_summary(value)
        self.assertIn("lineage must contain exactly one root node", errors)

    def test_duplicate_node_and_bad_digest_fail_closed(self):
        value = copy.deepcopy(summary())
        value["lineage"][1]["node_id"] = "root"
        value["lineage"][1]["digest"] = "bad"
        errors = validator.validate_summary(value)
        self.assertIn("lineage[1].node_id is duplicated", errors)
        self.assertIn("lineage[1].digest must be a lowercase 64-character digest", errors)


if __name__ == "__main__":
    unittest.main()
