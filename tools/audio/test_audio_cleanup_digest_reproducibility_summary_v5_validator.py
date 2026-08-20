"""Focused tests for v5 cross-record cleanup digest consensus."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_reproducibility_summary_v5_validator as validator  # noqa: E402


def summary() -> dict:
    roster = ["artifacts/audio/a.json", "artifacts/audio/b.json"]
    digest = "b" * 64
    input_digest = "c" * 64
    canonical = "json-sorted-v1"
    records = [{"record_id": "record-1", "timestamp_utc": "2026-08-20T12:00:00Z", "input_manifests": roster, "summary_sha256": digest, "input_sha256": input_digest, "canonicalization": canonical, "evidence": "artifacts/audio/record-1.json", "independent": True}, {"record_id": "record-2", "timestamp_utc": "2026-08-20T12:01:00Z", "input_manifests": roster, "summary_sha256": digest, "input_sha256": input_digest, "canonicalization": canonical, "evidence": "artifacts/audio/record-2.json", "independent": True}]
    return {"schema": "audio_cleanup_digest_reproducibility_summary_v5", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-repro-v5", "evidence_bundle": "artifacts/audio/repro-v5.json", "canonicalization": canonical, "claim": "AUTOMATED_CROSS_RECORD_ONLY", "boundary_note": "Cross-record consensus does not establish native audibility.", "algorithm": "SHA-256", "input_manifests": roster, "consensus_summary_sha256": digest, "consensus_input_sha256": input_digest, "consensus": True, "records": records}


class AudioCleanupDigestReproV5Tests(unittest.TestCase):
    def test_valid_cross_record_consensus(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_cross_record_digest_mismatch_is_rejected(self):
        value = copy.deepcopy(summary())
        value["records"][1]["summary_sha256"] = "d" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records.summary_sha256 digests must agree", errors)

    def test_roster_and_timestamp_contracts_are_required(self):
        value = copy.deepcopy(summary())
        value["input_manifests"] = list(reversed(value["input_manifests"]))
        value["records"][1]["timestamp_utc"] = value["records"][0]["timestamp_utc"]
        errors = validator.validate_summary(value)
        self.assertIn("input_manifests must be lexicographically ordered", errors)
        self.assertIn("records[1].timestamp_utc is duplicated", errors)

    def test_consensus_and_canonicalization_must_match(self):
        value = copy.deepcopy(summary())
        value["consensus"] = False
        value["records"][0]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("consensus must be true", errors)
        self.assertIn("records canonicalization must match summary canonicalization", errors)


if __name__ == "__main__":
    unittest.main()
