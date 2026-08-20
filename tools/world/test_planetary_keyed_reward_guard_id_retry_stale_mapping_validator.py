import copy
import unittest

from tools.world.planetary_keyed_reward_guard_id_retry_stale_mapping_validator import validate_mapping


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
    mappings = []
    for activity_id, authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        mappings.extend(
            [
                {
                    "activity_id": activity_id,
                    "kind": "retry",
                    "guard_id": f"{activity_id}_reward_retry_g2",
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
                    "guard_id": f"{activity_id}_reward_stale_g0",
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
        "evidence_scope": "planetary_keyed_reward_guard_id_retry_stale_mapping",
        "evidence_mode": "detached_keyed_guard_mapping",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "mapping_count": 10,
        "source_revision": "keyed-mapping-v1",
        "mappings": mappings,
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


class PlanetaryKeyedRewardGuardIdRetryStaleMappingValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_mapping(evidence()), [])

    def test_mapping_order_is_required(self):
        item = evidence()
        item["mappings"][0], item["mappings"][1] = item["mappings"][1], item["mappings"][0]
        errors = validate_mapping(item)
        self.assertTrue(any("kind must be retry" in error for error in errors))

    def test_retry_id_is_deterministic(self):
        item = evidence()
        item["mappings"][2]["guard_id"] = "wrong_retry_id"
        self.assertTrue(any("deterministic for the mapping" in error for error in validate_mapping(item)))

    def test_stale_mapping_is_rejected(self):
        item = evidence()
        item["mappings"][3]["rejected"] = False
        self.assertTrue(any("invalid mapping outcome" in error for error in validate_mapping(item)))

    def test_retry_generation_is_two(self):
        item = evidence()
        item["mappings"][4]["generation"] = 1
        self.assertTrue(any("generation must be 2" in error for error in validate_mapping(item)))

    def test_guard_ids_are_unique(self):
        item = evidence()
        item["mappings"][9]["guard_id"] = item["mappings"][1]["guard_id"]
        self.assertTrue(any("guard_ids must not contain duplicates" in error for error in validate_mapping(item)))

    def test_reward_pair_must_match(self):
        item = evidence()
        item["mappings"][7]["reward_id"] = "other_reward"
        self.assertTrue(any("share one reward ID" in error for error in validate_mapping(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_mapping(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
