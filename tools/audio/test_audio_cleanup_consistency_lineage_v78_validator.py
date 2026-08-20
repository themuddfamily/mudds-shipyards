"""Focused tests for v78 consistency/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_consistency_lineage_v78_validator as validator  # noqa: E402


def summary() -> dict:
    consistency, lineage = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "consistency_digest": consistency, "lineage_digest": lineage, "consistency_id": "consistency-v78", "lineage_id": "lineage-v78", "canonicalization": "json-sorted-v1", "evidence": evidence, "lineage_pass": True}
    return {"schema": "audio_cleanup_consistency_lineage_v78", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-consistency-lineage-v78", "evidence_bundle": "artifacts/audio/consistency-lineage-v78.json", "canonicalization": "json-sorted-v1", "consistency_id": "consistency-v78", "lineage_id": "lineage-v78", "claim": "AUTOMATED_CONSISTENCY_LINEAGE_ONLY", "boundary_note": "Consistency lineage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "consistency_digest": consistency, "lineage_digest": lineage, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "consistency_lineage_pass": True}


class AudioCleanupConsistencyLineageV78Tests(unittest.TestCase):
    def test_valid_consistency_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_lineage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_id"] = "other"
        self.assertIn("records[1].lineage_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["consistency_digest"] = "c" * 64
        self.assertIn("records consistency/lineage digest pairs must agree", validator.validate_summary(value))

    def test_lineage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["consistency_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("consistency_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
