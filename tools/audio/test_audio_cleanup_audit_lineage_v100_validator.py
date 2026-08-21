"""Focused tests for v100 audit/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_audit_lineage_v100_validator as validator  # noqa: E402


def summary() -> dict:
    audit, lineage = "a" * 64, "b" * 64
    def record(rid: str, evidence: str) -> dict:
        return {"record_id": rid, "audit_digest": audit, "lineage_digest": lineage, "audit_id": "audit-v100", "lineage_id": "lineage-v100", "canonicalization": "json-sorted-v1", "evidence": evidence, "lineage_pass": True}
    return {"schema": "audio_cleanup_audit_lineage_v100", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-audit-lineage-v100", "evidence_bundle": "artifacts/audio/audit-lineage-v100.json", "canonicalization": "json-sorted-v1", "audit_id": "audit-v100", "lineage_id": "lineage-v100", "claim": "AUTOMATED_AUDIT_LINEAGE_ONLY", "boundary_note": "Audit lineage does not establish native audibility.", "record_ids": ["record-a", "record-b"], "audit_digest": audit, "lineage_digest": lineage, "records": [record("record-a", "artifacts/audio/a.json"), record("record-b", "artifacts/audio/b.json")], "audit_lineage_pass": True}


class AudioCleanupAuditLineageV100Tests(unittest.TestCase):
    def test_valid_audit_lineage_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_lineage_binding_is_required(self):
        value = copy.deepcopy(summary())
        value["records"][1]["lineage_id"] = "other"
        self.assertIn("records[1].lineage_id must match summary", validator.validate_summary(value))

    def test_digest_pair_agreement_is_checked(self):
        value = copy.deepcopy(summary())
        value["records"][1]["audit_digest"] = "c" * 64
        self.assertIn("records audit/lineage digest pairs must agree", validator.validate_summary(value))

    def test_lineage_pass_flags_are_required(self):
        value = copy.deepcopy(summary())
        value["audit_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("audit_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
