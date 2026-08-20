import copy
import unittest

from tools.world.planetary_objective_reward_authority_join_validator import validate_join


def join() -> dict:
    ids = [
        ("ember_beacon_survey", "survey_beacon_network", "activity_director", "ember_beacon_data", "return_beacon_data_to_shipyard", "return_to_landed_ship"),
        ("ember_caldera_patrol", "complete_caldera_inspection", "activity_director", "ember_patrol_log", "return_patrol_log_to_shipyard", "abort_to_orbit_return"),
        ("ember_kit_cargo_run", "deliver_fabrication_kits", "cargo_delivery_activity", "ember_fabrication_kits", "return_kits_to_shipyard_berth", "return_to_landed_ship"),
        ("ember_checkpoint_race", "set_checkpoint_record", "timed_checkpoint_race", "ember_race_record", "return_race_record_to_shipyard", "reset_at_start_beacon"),
        ("ember_convoy_escort", "escort_emberline_convoy", "convoy_escort_activity", "ember_convoy_credit", "return_convoy_credit_to_shipyard", "recover_convoy_at_return_beacon"),
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_reward_authority_join",
        "evidence_mode": "detached_contract_fixture",
        "source_revision": "planetary-objective-reward-join-v1",
        "runtime_wired": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "recovery_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "authorities": {"reward": "game_flow_reward_authority", "reward_store": "game_flow_reward_store", "recovery": "planetary_landing_return_contract", "owns_reward_store": False},
        "activities": [
            {"activity_id": activity, "objective_id": objective, "activity_authority_id": activity_authority, "reward_id": reward, "reward_store_id": "game_flow_reward_store", "reward_authority_id": "game_flow_reward_authority", "return_incentive_id": incentive, "return_target_id": "mudds_shipyards", "recovery_id": recovery, "recovery_authority_id": "planetary_landing_return_contract", "objective_completed_once": True, "reward_granted_once": True}
            for activity, objective, activity_authority, reward, incentive, recovery in ids
        ],
        "evidence": {"historical_claim": False, "procedural_generation": False, "references": ["res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md"]},
        "authority": {"objective": False, "activity": False, "reward": False, "reward_store": False, "recovery": False, "save": False, "network": False, "gameplay": False},
    }


class PlanetaryObjectiveRewardAuthorityJoinValidatorTest(unittest.TestCase):
    def test_authored_join_is_valid(self):
        self.assertEqual(validate_join(join()), [])

    def test_unknown_activity_authority_fails(self):
        item = join(); item["activities"][0]["activity_authority_id"] = "new_activity_owner"
        self.assertTrue(any("existing activity authority" in error for error in validate_join(item)))

    def test_second_reward_store_fails(self):
        item = join(); item["activities"][1]["reward_store_id"] = "second_reward_store"
        self.assertTrue(any("one existing reward store" in error for error in validate_join(item)))

    def test_duplicate_reward_fails(self):
        item = join(); item["activities"][1]["reward_id"] = item["activities"][0]["reward_id"]
        self.assertTrue(any("reward_ids" in error for error in validate_join(item)))

    def test_return_incentive_targets_return(self):
        item = join(); item["activities"][0]["return_incentive_id"] = "bonus_only"
        self.assertTrue(any("begin with return_" in error for error in validate_join(item)))

    def test_recovery_authority_is_required(self):
        item = copy.deepcopy(join()); item["activities"][0]["recovery_authority_id"] = "local_recovery"
        self.assertTrue(any("recovery_authority_id" in error for error in validate_join(item)))

    def test_runtime_authority_stays_external(self):
        item = join(); item["authority"]["reward"] = True
        self.assertTrue(any("authority.reward" in error for error in validate_join(item)))

    def test_native_claim_is_rejected(self):
        item = join(); item["native_claims"] = True
        self.assertTrue(any("native_claims" in error for error in validate_join(item)))


if __name__ == "__main__":
    unittest.main()
