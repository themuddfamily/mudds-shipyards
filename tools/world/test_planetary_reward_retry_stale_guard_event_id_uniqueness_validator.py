import copy
import unittest

from tools.world.planetary_reward_retry_stale_guard_event_id_uniqueness_validator import validate_catalog


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
    guards = []
    for activity_id, authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        guards.extend(
            [
                {
                    "activity_id": activity_id,
                    "kind": "retry",
                    "event_id": f"{activity_id}_reward_retry_g2",
                    "generation": 2,
                    "accepted": True,
                    "rejected": False,
                    "reward_id": reward_id,
                    "activity_authority_id": authority,
                    "reward_authority_id": "game_flow_reward_authority",
                    "reward_store_id": "game_flow_reward_store",
                    "committed_once": True,
                },
                {
                    "activity_id": activity_id,
                    "kind": "stale",
                    "event_id": f"{activity_id}_reward_stale_g0",
                    "generation": 0,
                    "accepted": False,
                    "rejected": True,
                    "reward_id": reward_id,
                    "activity_authority_id": authority,
                    "reward_authority_id": "game_flow_reward_authority",
                    "reward_store_id": "game_flow_reward_store",
                    "committed_once": True,
                },
            ]
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_retry_stale_guard_event_id_uniqueness",
        "evidence_mode": "detached_reward_guard_id_catalog",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "guard_count": 10,
        "source_revision": "guard-uniqueness-v1",
        "guards": guards,
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


class PlanetaryRewardRetryStaleGuardEventIdUniquenessValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_catalog(evidence()), [])

    def test_retry_and_stale_ids_are_unique(self):
        item = evidence()
        item["guards"][9]["event_id"] = item["guards"][1]["event_id"]
        self.assertTrue(any("guard_ids must not contain duplicates" in error for error in validate_catalog(item)))

    def test_guard_order_is_required(self):
        item = evidence()
        item["guards"][0], item["guards"][1] = item["guards"][1], item["guards"][0]
        self.assertTrue(any("kind must be retry" in error for error in validate_catalog(item)))

    def test_retry_generation_is_two(self):
        item = evidence()
        item["guards"][2]["generation"] = 1
        self.assertTrue(any("generation must be 2" in error for error in validate_catalog(item)))

    def test_stale_generation_is_zero(self):
        item = evidence()
        item["guards"][3]["generation"] = 1
        self.assertTrue(any("generation must be 0" in error for error in validate_catalog(item)))

    def test_retry_and_stale_share_reward(self):
        item = evidence()
        item["guards"][7]["reward_id"] = "other_reward"
        self.assertTrue(any("share one activity reward ID" in error for error in validate_catalog(item)))

    def test_reward_store_is_canonical(self):
        item = evidence()
        item["guards"][5]["reward_store_id"] = "new_reward_store"
        self.assertTrue(any("canonical reward store" in error for error in validate_catalog(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_catalog(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
