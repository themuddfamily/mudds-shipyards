"""Focused tests for v6 cleanup input-roster integrity summaries."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import audio_cleanup_digest_input_roster_integrity_summary_v6_validator as validator  # noqa: E402


def summary() -> dict:
    roster = ["artifacts/audio/a.json", "artifacts/audio/b.json"]
    digest = "c" * 64
    canonical = "json-sorted-v1"
    records = [{"record_id": "record-1", "input_manifests": roster, "canonical_input_sha256": digest, "canonicalization": canonical, "evidence": "artifacts/audio/roster-1.json", "integrity_pass": True}, {"record_id": "record-2", "input_manifests": roster, "canonical_input_sha256": digest, "canonicalization": canonical, "evidence": "artifacts/audio/roster-2.json", "integrity_pass": True}]
    return {"schema": "audio_cleanup_digest_input_roster_integrity_summary_v6", "revision": "a" * 40, "owner": "audio-evidence-owner", "summary_id": "cleanup-roster-v6", "evidence_bundle": "artifacts/audio/roster-v6.json", "canonicalization": canonical, "claim": "AUTOMATED_ROSTER_INTEGRITY_ONLY", "boundary_note": "Roster integrity does not establish native audibility.", "algorithm": "SHA-256", "input_manifests": roster, "canonical_input_sha256": digest, "integrity_pass": True, "records": records}


class AudioCleanupRosterV6Tests(unittest.TestCase):
    def test_valid_roster_integrity_summary(self):
        self.assertEqual(validator.validate_summary(summary()), [])

    def test_roster_order_and_duplicates_are_rejected(self):
        value = copy.deepcopy(summary())
        value["input_manifests"] = ["artifacts/audio/b.json", "artifacts/audio/a.json", "artifacts/audio/a.json"]
        errors = validator.validate_summary(value)
        self.assertIn("input_manifests must be ordered, unique, and non-empty", errors)

    def test_canonical_input_digests_must_agree(self):
        value = copy.deepcopy(summary())
        value["records"][1]["canonical_input_sha256"] = "d" * 64
        errors = validator.validate_summary(value)
        self.assertIn("records canonical_input_sha256 digests must agree", errors)

    def test_record_rosters_and_canonicalization_must_match(self):
        value = copy.deepcopy(summary())
        value["records"][1]["input_manifests"] = ["artifacts/audio/other.json"]
        value["records"][0]["canonicalization"] = "other"
        errors = validator.validate_summary(value)
        self.assertIn("records[1].input_manifests must match ordered summary roster", errors)
        self.assertIn("records[0].canonicalization must match summary canonicalization", errors)


if __name__ == "__main__":
    unittest.main()
