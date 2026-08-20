"""Focused tests for v68 evidence/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_evidence_lineage_v68_validator as validator  # noqa: E402


def summary() -> dict:
    evidence, lineage = "a" * 64, "b" * 64
    def record(rid: str, artifact: str) -> dict:
        return {"record_id": rid, "evidence_digest": evidence, "lineage_digest": lineage, "evidence_id": "evidence-v68", "lineage_id": "lineage-v68", "canonicalization": "json-sorted-v1", "evidence": artifact, "lineage_pass": True}
    return {"schema": "audio_cleanup_evidence_lineage_v68", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-lineage-v68", "evidence_bundle": "artifacts/audio/lineage-v68.json", "canonicalization": "json-sorted-v1", "evidence_id": "evidence-v68", "lineage_id": "lineage-v68", "claim": "AUTOMATED_EVIDENCE_LINEAGE_ONLY", "boundary_note": "Evidence lineage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "evidence_digest": evidence, "lineage_digest": lineage, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "evidence_lineage_pass": True}


class AudioCleanupEvidenceLineageV68Tests(unittest.TestCase):
    def test_valid_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_lineage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_id"] = "other"
        self.assertIn("records[1].lineage_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["evidence_digest"] = "c" * 64
        self.assertIn("records evidence/lineage digest pairs must agree", validator.validate_summary(value))

    def test_lineage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["evidence_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("evidence_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
