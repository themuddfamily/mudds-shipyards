import copy
import unittest

from tools.world.planetary_activity_objective_state_validator import validate_transitions


def evidence() -> dict:
    activity_ids = [
        ("ember_beacon_survey", "survey_beacon_network"),
        ("ember_caldera_patrol", "complete_caldera_inspection"),
        ("ember_kit_cargo_run", "deliver_fabrication_kits"),
        ("ember_checkpoint_race", "set_checkpoint_record"),
        ("ember_convoy_escort", "escort_emberline_convoy"),
    ]
    success = ["idle", "active", "completed", "reward_queued", "return_presented", "returned"]
    failure = ["active", "failed", "recovered", "reset"]
    observations = [
        {"from": "idle", "to": "active", "sequence": 0, "generation": 1, "accepted": True, "committed_once": True},
        {"from": "active", "to": "completed", "sequence": 1, "generation": 1, "accepted": True, "committed_once": True},
        {"from": "completed", "to": "reward_queued", "sequence": 2, "generation": 1, "accepted": True, "committed_once": True},
        {"from": "reward_queued", "to": "return_presented", "sequence": 3, "generation": 1, "accepted": True, "committed_once": True},
        {"from": "return_presented", "to": "returned", "sequence": 4, "generation": 1, "accepted": True, "committed_once": True},
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_activity_objective_state",
        "evidence_mode": "detached_transition_fixture",
        "source_revision": "activity-state-v1",
        "runtime_authority": False,
        "objective_mutated": False,
        "reward_granted": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "activities": [
            {"activity_id": activity_id, "objective_id": objective_id, "generation": 1, "success_path": success, "failure_path": failure, "completed_once": True, "reward_queued_once": True, "return_presented_once": True, "failure_recovered": True, "stale_generation_rejected": True, "duplicate_completion_rejected": True, "duplicate_reward_rejected": True, "observations": copy.deepcopy(observations)}
            for activity_id, objective_id in activity_ids
        ],
        "stale_attempt": {"accepted": False, "reason": "stale_generation", "submitted_generation": 1, "current_generation": 2},
        "authority": {"activity": False, "objective": False, "reward": False, "recovery": False, "save": False, "network": False, "gameplay": False, "clock": False},
    }


class PlanetaryActivityObjectiveStateValidatorTest(unittest.TestCase):
    def test_transition_fixture_is_valid(self):
        self.assertEqual(validate_transitions(evidence()), [])

    def test_activity_order_is_required(self):
        item = evidence(); item["activities"].reverse()
        self.assertTrue(any("authored activity order" in error for error in validate_transitions(item)))

    def test_success_path_is_required(self):
        item = evidence(); item["activities"][0]["success_path"] = ["idle", "active", "returned"]
        self.assertTrue(any("exact success transition" in error for error in validate_transitions(item)))

    def test_duplicate_completion_guard_is_required(self):
        item = evidence(); item["activities"][1]["duplicate_completion_rejected"] = False
        self.assertTrue(any("duplicate_completion_rejected" in error for error in validate_transitions(item)))

    def test_observation_generation_must_match(self):
        item = evidence(); item["activities"][0]["observations"][1]["generation"] = 2
        self.assertTrue(any("match activity generation" in error for error in validate_transitions(item)))

    def test_stale_attempt_must_be_rejected(self):
        item = evidence(); item["stale_attempt"]["accepted"] = True
        self.assertTrue(any("stale_attempt.accepted" in error for error in validate_transitions(item)))

    def test_runtime_authority_stays_external(self):
        item = copy.deepcopy(evidence()); item["authority"]["activity"] = True
        self.assertTrue(any("authority.activity" in error for error in validate_transitions(item)))

    def test_native_claim_fails_closed(self):
        item = evidence(); item["native_claims"] = True
        self.assertTrue(any("native_claims" in error for error in validate_transitions(item)))


if __name__ == "__main__":
    unittest.main()
