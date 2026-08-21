"""Focused tests for v113 audio cleanup evidence/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_lineage_v113_validator as validator  # noqa: E402


def summary() -> dict:
    evidence, root = "a" * 64, "b" * 64

    def record(record_id: str, leaf: str, artifact: str) -> dict:
        return {"record_id": record_id, "evidence_digest": evidence, "lineage_root": root,
                "lineage_leaf": leaf, "evidence_id": "evidence-v113", "lineage_id": "lineage-v1",
                "evidence": artifact, "lineage_pass": True}

    return {"schema": "audio_cleanup_evidence_lineage_v113", "revision": "a" * 40,
            "owner": "audio-evidence-owner", "summary_id": "cleanup-evidence-lineage-v113",
            "evidence_bundle": "artifacts/audio/evidence-lineage-v113.json",
            "evidence_id": "evidence-v113", "lineage_id": "lineage-v1",
            "claim": "AUTOMATED_EVIDENCE_LINEAGE_ONLY",
            "boundary_note": "Evidence lineage does not establish native audibility.",
            "evidence_digest": evidence, "lineage_root": root,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "c" * 64, "artifacts/audio/a.json"),
                record("record-b", "d" * 64, "artifacts/audio/b.json")],
            "evidence_lineage_pass": True}


class AudioCleanupEvidenceLineageV113Tests(unittest.TestCase):
    def test_valid_evidence_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_root_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_root"] = "e" * 64
        self.assertIn("records[1].lineage_root must match summary", validator.validate_summary(value))

    def test_leaf_digests_must_be_unique(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_leaf"] = value["records"][0]["lineage_leaf"]
        self.assertIn("records lineage_leaf digests must be unique", validator.validate_summary(value))

    def test_lineage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["evidence_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("evidence_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
