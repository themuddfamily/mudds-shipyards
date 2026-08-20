import copy
import unittest

from tools.world.planetary_objective_contiguous_event_reward_mapping_ledger import validate_mapping


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
    event_types = (
        "objective_started",
        "objective_completed",
        "reward_queued",
        "reward_granted",
        "return_presented",
        "returned",
    )
    activities = []
    for activity_id, activity_authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        incentive_id = f"return_{activity_id}"
        mappings = []
        for sequence, event_type in enumerate(event_types):
            mapping = {
                "event_type": event_type,
                "event_id": f"{activity_id}_{event_type}",
                "sequence": sequence,
                "occurrence": 1,
                "reward_id": reward_id if event_type in {"reward_queued", "reward_granted"} else None,
                "reward_store_id": "game_flow_reward_store" if event_type in {"reward_queued", "reward_granted"} else None,
                "return_incentive_id": incentive_id if event_type in {"return_presented", "returned"} else None,
                "return_target_id": "mudds_shipyards" if event_type in {"return_presented", "returned"} else None,
            }
            mappings.append(mapping)
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
                "mappings": mappings,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_contiguous_event_reward_mapping",
        "evidence_mode": "detached_event_reward_mapping",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "return_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "reward_store_id": "game_flow_reward_store",
        "reward_store_ids": ["game_flow_reward_store"],
        "source_revision": "event-reward-mapping-v1",
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


class PlanetaryObjectiveContiguousEventRewardMappingLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_mapping(evidence()), [])

    def test_reward_event_maps_to_reward_store(self):
        item = evidence()
        item["activities"][0]["mappings"][2]["reward_store_id"] = None
        self.assertTrue(any("canonical reward store" in error for error in validate_mapping(item)))

    def test_return_event_maps_to_incentive(self):
        item = evidence()
        item["activities"][1]["mappings"][4]["return_incentive_id"] = None
        self.assertTrue(any("map to the activity incentive" in error for error in validate_mapping(item)))

    def test_pre_reward_event_cannot_map_reward(self):
        item = evidence()
        item["activities"][2]["mappings"][1]["reward_id"] = "reward_ember_kit_cargo_run"
        self.assertTrue(any("must not map a reward before" in error for error in validate_mapping(item)))

    def test_mapping_order_is_required(self):
        item = evidence()
        item["activities"][3]["mappings"][2], item["activities"][3]["mappings"][3] = item["activities"][3]["mappings"][3], item["activities"][3]["mappings"][2]
        self.assertTrue(any("authored event order" in error for error in validate_mapping(item)))

    def test_reward_ids_are_unique(self):
        item = evidence()
        item["activities"][4]["reward_id"] = item["activities"][0]["reward_id"]
        self.assertTrue(any("reward_ids must not contain duplicates" in error for error in validate_mapping(item)))

    def test_event_ids_are_unique(self):
        item = evidence()
        item["activities"][4]["mappings"][5]["event_id"] = item["activities"][0]["mappings"][5]["event_id"]
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
