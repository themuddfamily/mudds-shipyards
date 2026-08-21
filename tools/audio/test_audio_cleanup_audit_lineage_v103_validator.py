"""Focused tests for v103 audio cleanup audit/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_audit_lineage_v103_validator as validator  # noqa: E402


def summary() -> dict:
    root, audit = "a" * 64, "b" * 64

    def record(record_id: str, leaf: str, artifact: str) -> dict:
        return {"record_id": record_id, "audit_digest": audit, "lineage_root": root,
                "lineage_leaf": leaf, "audit_id": "audit-v103", "lineage_id": "lineage-v1",
                "audit": artifact, "lineage_pass": True}

    return {"schema": "audio_cleanup_audit_lineage_v103", "revision": "a" * 40,
            "owner": "audio-audit-owner", "summary_id": "cleanup-audit-lineage-v103",
            "audit_bundle": "artifacts/audio/audit-lineage-v103.json", "audit_id": "audit-v103",
            "lineage_id": "lineage-v1", "claim": "AUTOMATED_AUDIT_LINEAGE_ONLY",
            "boundary_note": "Audit lineage does not establish native audibility.",
            "lineage_root": root, "audit_digest": audit, "record_ids": ["record-a", "record-b"],
            "records": [record("record-a", "c" * 64, "artifacts/audio/a.json"),
                        record("record-b", "d" * 64, "artifacts/audio/b.json")],
            "audit_lineage_pass": True}


class AudioCleanupAuditLineageV103Tests(unittest.TestCase):
    def test_valid_audit_lineage_summary(self):
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
        value["audit_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("audit_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
