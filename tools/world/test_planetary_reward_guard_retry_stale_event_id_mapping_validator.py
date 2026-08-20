import copy
import unittest

from tools.world.planetary_reward_guard_retry_stale_event_id_mapping_validator import validate_mapping


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
    for activity_id, authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": authority,
                "reward_authority_id": "game_flow_reward_authority",
                "reward_id": reward_id,
                "retry_guard": {
                    "event_id": f"{activity_id}_reward_retry_g2",
                    "submitted_generation": 2,
                    "source_generation": 1,
                    "current_generation": 2,
                    "accepted": True,
                    "rejected": False,
                    "reward_id": reward_id,
                    "reward_store_id": "game_flow_reward_store",
                    "committed_once": True,
                },
                "stale_guard": {
                    "event_id": f"{activity_id}_reward_stale_g0",
                    "submitted_generation": 0,
                    "source_generation": 0,
                    "current_generation": 2,
                    "accepted": False,
                    "rejected": True,
                    "reason": "stale_generation",
                    "reward_id": reward_id,
                    "reward_store_id": "game_flow_reward_store",
                    "committed_once": True,
                },
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_guard_retry_stale_event_id_mapping",
        "evidence_mode": "detached_reward_retry_stale_mapping",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "source_revision": "retry-stale-mapping-v1",
        "activities": activities,
        "authority": {
            "activity": False,
            "objective": False,
            "reward": False,
            "reward_store": False,
            "save": False,
            "network": False,
            "gameplay": False,
        },
    }


class PlanetaryRewardGuardRetryStaleEventIdMappingValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_mapping(evidence()), [])

    def test_retry_id_is_deterministic(self):
        item = evidence()
        item["activities"][0]["retry_guard"]["event_id"] = "wrong_id"
        self.assertTrue(any("deterministic for the guard" in error for error in validate_mapping(item)))

    def test_retry_maps_generation_one_to_two(self):
        item = evidence()
        item["activities"][1]["retry_guard"]["source_generation"] = 2
        self.assertTrue(any("source generation one" in error for error in validate_mapping(item)))

    def test_stale_maps_generation_zero_to_two(self):
        item = evidence()
        item["activities"][2]["stale_guard"]["current_generation"] = 1
        self.assertTrue(any("stale generation zero" in error for error in validate_mapping(item)))

    def test_stale_reason_is_required(self):
        item = evidence()
        item["activities"][3]["stale_guard"]["reason"] = "other_reason"
        self.assertTrue(any("reason must be stale_generation" in error for error in validate_mapping(item)))

    def test_guard_ids_are_unique(self):
        item = evidence()
        item["activities"][4]["stale_guard"]["event_id"] = item["activities"][0]["stale_guard"]["event_id"]
        self.assertTrue(any("guard_ids must not contain duplicates" in error for error in validate_mapping(item)))

    def test_reward_store_is_canonical(self):
        item = evidence()
        item["activities"][0]["retry_guard"]["reward_store_id"] = "new_reward_store"
        self.assertTrue(any("canonical reward store" in error for error in validate_mapping(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_mapping(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
