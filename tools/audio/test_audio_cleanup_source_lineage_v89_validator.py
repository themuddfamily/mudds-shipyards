"""Focused tests for v89 source/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_source_lineage_v89_validator as validator  # noqa: E402


def summary() -> dict:
    source, lineage = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "source_digest": source, "lineage_digest": lineage, "source_id": "source-v89", "lineage_id": "lineage-v89", "canonicalization": "json-sorted-v1", "evidence": evidence, "lineage_pass": True}
    return {"schema": "audio_cleanup_source_lineage_v89", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-source-lineage-v89", "evidence_bundle": "artifacts/audio/source-lineage-v89.json", "canonicalization": "json-sorted-v1", "source_id": "source-v89", "lineage_id": "lineage-v89", "claim": "AUTOMATED_SOURCE_LINEAGE_ONLY", "boundary_note": "Source lineage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "source_digest": source, "lineage_digest": lineage, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "source_lineage_pass": True}


class AudioCleanupSourceLineageV89Tests(unittest.TestCase):
    def test_valid_source_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_lineage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_id"] = "other"
        self.assertIn("records[1].lineage_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["source_digest"] = "c" * 64
        self.assertIn("records source/lineage digest pairs must agree", validator.validate_summary(value))

    def test_lineage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["source_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("source_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
