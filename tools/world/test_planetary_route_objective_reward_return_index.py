import copy
import unittest

from tools.world.planetary_route_objective_reward_return_index import validate_index


def index() -> dict:
    activities = ["ember_beacon_survey", "ember_caldera_patrol", "ember_kit_cargo_run", "ember_checkpoint_race", "ember_convoy_escort"]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_route_objective_reward_return_index",
        "evidence_mode": "detached_authored_index",
        "source_revision": "route-objective-index-v1",
        "route_runtime": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "movement_authority": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "nodes": [
            {"id": "orbit", "role": "orbit_approach"},
            {"id": "pad", "role": "landing_pad"},
            {"id": "settlement", "role": "settlement"},
            {"id": "beacon", "role": "return_beacon"},
            {"id": "shipyard", "role": "shipyard_return"},
        ],
        "return_routes": [{"id": "ember_return_route", "nodes": ["beacon", "shipyard"], "destination": "mudds_shipyards", "return_complete": True}],
        "records": [
            {"activity_id": activity_id, "objective_id": f"objective_{number}", "reward_id": f"reward_{number}", "route_id": f"route_{number}", "return_incentive_id": f"return_reward_{number}", "return_route_id": "ember_return_route", "start_node_id": "pad", "finish_node_id": "settlement", "activity_authority_id": "activity_director", "reward_authority_id": "game_flow_reward_authority", "reward_store_id": "game_flow_reward_store", "return_target_id": "mudds_shipyards", "recovery_id": "return_to_landed_ship", "recovery_authority_id": "planetary_landing_return_contract", "evidence_ref": "res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md"}
            for number, activity_id in enumerate(activities, start=1)
        ],
        "authority": {"route": False, "objective": False, "activity": False, "reward": False, "reward_store": False, "recovery": False, "movement": False, "save": False, "network": False},
    }


class PlanetaryRouteObjectiveRewardReturnIndexTest(unittest.TestCase):
    def test_authored_index_is_valid(self):
        self.assertEqual(validate_index(index()), [])

    def test_unknown_start_node_fails(self):
        item = index(); item["records"][0]["start_node_id"] = "missing"
        self.assertTrue(any("authored start and finish" in error for error in validate_index(item)))

    def test_return_route_must_target_shipyard(self):
        item = index(); item["return_routes"][0]["destination"] = "other_station"
        self.assertTrue(any("destination" in error for error in validate_index(item)))

    def test_duplicate_reward_fails(self):
        item = index(); item["records"][1]["reward_id"] = item["records"][0]["reward_id"]
        self.assertTrue(any("reward_ids" in error for error in validate_index(item)))

    def test_second_route_id_fails(self):
        item = index(); item["records"][1]["route_id"] = item["records"][0]["route_id"]
        self.assertTrue(any("route_ids" in error for error in validate_index(item)))

    def test_incentive_must_target_return(self):
        item = index(); item["records"][0]["return_incentive_id"] = "bonus_only"
        self.assertTrue(any("begin with return_" in error for error in validate_index(item)))

    def test_reward_store_is_canonical(self):
        item = copy.deepcopy(index()); item["records"][0]["reward_store_id"] = "second_store"
        self.assertTrue(any("canonical store" in error for error in validate_index(item)))

    def test_runtime_authority_stays_external(self):
        item = index(); item["authority"]["route"] = True
        self.assertTrue(any("authority.route" in error for error in validate_index(item)))


if __name__ == "__main__":
    unittest.main()
