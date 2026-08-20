"""Focused tests for the packaged flight-tuning evidence contract."""

import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flight_tuning_manifest_validator as validator  # noqa: E402


def manifest() -> dict:
    return {
        "schema": "flight_tuning_manifest_v1",
        "tuning_status": "AWAITING_HUMAN_REVIEW",
        "packaged_candidate": {
            "candidate_id": "build-2026-08-20-flight-01",
            "artifact": "artifacts/packages/flight-01.zip",
            "source_revision": "abc1234",
        },
        "human_playtest": {"status": "NOT_RUN", "participants": 0, "evidence": None},
        "trials": [
            {"id": "input-60hz", "dimension": "input", "scenario": "guided_sortie", "sampling_rate_hz": 60, "samples": 3, "metrics": {"clarity_score": 4}, "evidence": ["input-trial.json"]},
            {"id": "camera-60hz", "dimension": "camera", "scenario": "chase_and_cockpit", "sampling_rate_hz": 60, "samples": 3, "metrics": {"comfort_score": 4}, "evidence": ["camera-trial.json"]},
            {"id": "landing-60hz", "dimension": "landing", "scenario": "return_to_berth", "sampling_rate_hz": 60, "samples": 3, "metrics": {"landing_score": 4}, "evidence": ["landing-trial.json"]},
        ],
    }


class FlightTuningManifestTests(unittest.TestCase):
    def test_valid_manifest_can_explicitly_remain_unplayed(self):
        self.assertEqual(validator.validate_manifest(manifest()), [])

    def test_missing_dimension_and_bad_score_fail(self):
        value = copy.deepcopy(manifest())
        value["trials"] = value["trials"][:2]
        value["trials"][0]["metrics"]["clarity_score"] = 6
        errors = validator.validate_manifest(value)
        self.assertIn("trials[0].metrics.clarity_score must be an integer from 1 to 5", errors)
        self.assertIn("trials missing dimensions: landing", errors)

    def test_human_completion_requires_evidence_and_participant(self):
        value = copy.deepcopy(manifest())
        value["human_playtest"] = {"status": "COMPLETE", "participants": 0, "evidence": None}
        errors = validator.validate_manifest(value)
        self.assertIn("human_playtest.evidence is required when a human run started", errors)
        self.assertIn("human_playtest.participants must be positive when status is COMPLETE", errors)

    def test_completion_claim_is_not_an_allowed_tuning_status(self):
        value = copy.deepcopy(manifest())
        value["tuning_status"] = "COMPLETE"
        self.assertIn("tuning_status must remain IN_PROGRESS, BLOCKED, or AWAITING_HUMAN_REVIEW", validator.validate_manifest(value))


if __name__ == "__main__":
    unittest.main()
