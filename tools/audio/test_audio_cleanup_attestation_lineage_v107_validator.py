"""Focused tests for v107 audio cleanup attestation/lineage summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_attestation_lineage_v107_validator as validator  # noqa: E402


def summary() -> dict:
    attestation, root = "a" * 64, "b" * 64

    def record(record_id: str, leaf: str, artifact: str) -> dict:
        return {"record_id": record_id, "attestation_digest": attestation,
                "lineage_root": root, "lineage_leaf": leaf,
                "attestation_id": "attestation-v107", "lineage_id": "lineage-v1",
                "attestation": artifact, "lineage_pass": True}

    return {"schema": "audio_cleanup_attestation_lineage_v107", "revision": "a" * 40,
            "owner": "audio-attestation-owner", "summary_id": "cleanup-attestation-lineage-v107",
            "attestation_bundle": "artifacts/audio/attestation-lineage-v107.json",
            "attestation_id": "attestation-v107", "lineage_id": "lineage-v1",
            "claim": "AUTOMATED_ATTESTATION_LINEAGE_ONLY",
            "boundary_note": "Attestation lineage does not establish native audibility.",
            "attestation_digest": attestation, "lineage_root": root,
            "record_ids": ["record-a", "record-b"], "records": [
                record("record-a", "c" * 64, "artifacts/audio/a.json"),
                record("record-b", "d" * 64, "artifacts/audio/b.json")],
            "attestation_lineage_pass": True}


class AudioCleanupAttestationLineageV107Tests(unittest.TestCase):
    def test_valid_attestation_lineage_summary(self):
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
        value["attestation_lineage_pass"] = False
        value["records"][0]["lineage_pass"] = False
        errors = validator.validate_summary(value)
        self.assertIn("attestation_lineage_pass must be true", errors)
        self.assertIn("records[0].lineage_pass must be true", errors)


if __name__ == "__main__":
    unittest.main()
