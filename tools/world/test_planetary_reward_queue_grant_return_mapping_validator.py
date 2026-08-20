import copy
import unittest

from tools.world.planetary_reward_queue_grant_return_mapping_validator import validate_mapping


def evidence() -> dict:
    activity_ids = (
        "ember_beacon_survey",
        "ember_caldera_patrol",
        "ember_kit_cargo_run",
        "ember_checkpoint_race",
        "ember_convoy_escort",
    )
    authorities = (
        "activity_director",
        "activity_director",
        "cargo_delivery_activity",
        "timed_checkpoint_race",
        "convoy_escort_activity",
    )
    activities = []
    for activity_id, activity_authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        incentive_id = f"return_{activity_id}"
        completion_id = f"{activity_id}_objective_completed"
        queue_id = f"{activity_id}_reward_queued"
        grant_id = f"{activity_id}_reward_granted"
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": activity_authority,
                "reward_authority_id": "game_flow_reward_authority",
                "return_authority_id": "planetary_landing_return_contract",
                "return_target_id": "mudds_shipyards",
                "reward_id": reward_id,
                "return_incentive_id": incentive_id,
                "objective_completed_event_id": completion_id,
                "reward_queue": {
                    "type": "reward_queued",
                    "event_id": queue_id,
                    "sequence": 0,
                    "occurrence": 1,
                    "committed_once": True,
                    "objective_completed_event_id": completion_id,
                    "reward_id": reward_id,
                    "reward_store_id": "game_flow_reward_store",
                    "queued_once": True,
                },
                "reward_grant": {
                    "type": "reward_granted",
                    "event_id": grant_id,
                    "sequence": 1,
                    "occurrence": 1,
                    "committed_once": True,
                    "reward_id": reward_id,
                    "reward_store_id": "game_flow_reward_store",
                    "granted_once": True,
                    "duplicate_grant_rejected": True,
                },
                "return_event": {
                    "type": "return_presented",
                    "event_id": f"{activity_id}_return_presented",
                    "sequence": 2,
                    "occurrence": 1,
                    "committed_once": True,
                    "reward_grant_event_id": grant_id,
                    "return_incentive_id": incentive_id,
                    "return_target_id": "mudds_shipyards",
                    "presented_once": True,
                    "returned_once": True,
                },
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_queue_grant_return_mapping",
        "evidence_mode": "detached_reward_lifecycle_mapping",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "return_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "reward_store_id": "game_flow_reward_store",
        "reward_store_ids": ["game_flow_reward_store"],
        "source_revision": "reward-lifecycle-v1",
        "activities": activities,
        "authority": {
            "activity": False,
            "objective": False,
            "reward": False,
            "reward_store": False,
            "return": False,
            "save": False,
            "network": False,
            "gameplay": False,
        },
    }


class PlanetaryRewardQueueGrantReturnMappingValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_mapping(evidence()), [])

    def test_queue_must_precede_grant(self):
        item = evidence()
        item["activities"][0]["reward_grant"]["sequence"] = 0
        self.assertTrue(any("sequence must be 1" in error for error in validate_mapping(item)))

    def test_queue_and_grant_share_reward(self):
        item = evidence()
        item["activities"][1]["reward_grant"]["reward_id"] = "other_reward"
        self.assertTrue(any("share the activity reward ID" in error for error in validate_mapping(item)))

    def test_grant_duplicate_is_rejected(self):
        item = evidence()
        item["activities"][2]["reward_grant"]["duplicate_grant_rejected"] = False
        self.assertTrue(any("duplicate rejection" in error for error in validate_mapping(item)))

    def test_return_must_reference_grant(self):
        item = evidence()
        item["activities"][3]["return_event"]["reward_grant_event_id"] = "other_grant"
        self.assertTrue(any("reference reward grant" in error for error in validate_mapping(item)))

    def test_return_target_is_mudds(self):
        item = evidence()
        item["activities"][4]["return_event"]["return_target_id"] = "other_destination"
        self.assertTrue(any("return_target_id must be mudds_shipyards" in error for error in validate_mapping(item)))

    def test_event_ids_are_unique(self):
        item = evidence()
        item["activities"][4]["reward_grant"]["event_id"] = item["activities"][0]["reward_grant"]["event_id"]
        self.assertTrue(any("event_ids must not contain duplicates" in error for error in validate_mapping(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_mapping(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
