import copy
import unittest

from tools.world.planetary_activity_settlement_reward_recovery_ledger import validate_ledger


def ledger() -> dict:
    ids = [
        ("ember_settlement_supply_run", "supply_run", "cargo_delivery_activity", "ember_settlement_supplies", "return_settlement_supplies_to_shipyard", "return_to_landed_ship"),
        ("ember_relay_repair", "repair_relay", "activity_director", "ember_relay_repair_data", "return_relay_data_to_shipyard", "recover_at_surface_shelter"),
        ("ember_shelter_recovery", "recover_shelter", "activity_director", "ember_shelter_access", "return_shelter_access_to_shipyard", "abort_to_orbit_return"),
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_activity_settlement_reward_recovery",
        "evidence_mode": "detached_ledger_fixture",
        "source_revision": "settlement-reward-ledger-v1",
        "runtime_wired": False,
        "reward_inventory": False,
        "objective_resolution": False,
        "recovery_mutation": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "settlement_id": "ember_caldera_settlement",
        "return_target_id": "mudds_shipyards",
        "landmarks": {"ember_settlement_gate": "route_gate_relay", "ember_relay_tower": "route_relay_fabrication", "ember_fabrication_crane": "route_relay_fabrication", "ember_return_beacon": "ember_return_route"},
        "activities": [
            {"activity_id": activity, "objective_id": objective, "activity_authority_id": authority, "reward_id": reward, "reward_store_id": "game_flow_reward_store", "reward_authority_id": "game_flow_reward_authority", "return_incentive_id": incentive, "return_target_id": "mudds_shipyards", "recovery_id": recovery, "recovery_authority_id": "planetary_landing_return_contract", "start_landmark_id": "ember_settlement_gate", "finish_landmark_id": "ember_return_beacon", "activity_route_id": "route_gate_relay", "return_route_id": "ember_return_route", "reward_grant_once": True, "retryable": True}
            for activity, objective, authority, reward, incentive, recovery in ids
        ],
        "ledger_events": [
            {"id": "objective_completed", "sequence": 0, "committed_once": True},
            {"id": "reward_queued", "sequence": 1, "committed_once": True},
            {"id": "return_incentive_presented", "sequence": 2, "committed_once": True},
            {"id": "recovery_registered", "sequence": 3, "committed_once": True},
            {"id": "settlement_return", "sequence": 4, "committed_once": True},
        ],
        "evidence": {"historical_claim": False, "procedural_generation": False, "references": ["res://docs/PLANETARY_DESTINATION_CONTENT_CONTRACT.md"]},
        "authority": {"objective": False, "activity": False, "reward": False, "reward_store": False, "recovery": False, "save": False, "network": False, "gameplay": False},
    }


class PlanetaryActivitySettlementRewardRecoveryLedgerTest(unittest.TestCase):
    def test_authored_ledger_is_valid(self):
        self.assertEqual(validate_ledger(ledger()), [])

    def test_landmark_references_are_required(self):
        item = ledger(); item["activities"][0]["start_landmark_id"] = "missing"
        self.assertTrue(any("declared settlement landmarks" in error for error in validate_ledger(item)))

    def test_duplicate_reward_fails(self):
        item = ledger(); item["activities"][1]["reward_id"] = item["activities"][0]["reward_id"]
        self.assertTrue(any("reward_ids" in error for error in validate_ledger(item)))

    def test_second_reward_store_fails(self):
        item = ledger(); item["activities"][2]["reward_store_id"] = "second_store"
        self.assertTrue(any("canonical reward store" in error for error in validate_ledger(item)))

    def test_recovery_must_be_existing(self):
        item = ledger(); item["activities"][0]["recovery_id"] = "new_recovery"
        self.assertTrue(any("existing recovery" in error for error in validate_ledger(item)))

    def test_ledger_event_order_is_required(self):
        item = ledger(); item["ledger_events"].reverse()
        self.assertTrue(any("exact ordered outcome" in error for error in validate_ledger(item)))

    def test_runtime_authority_stays_external(self):
        item = copy.deepcopy(ledger()); item["authority"]["reward"] = True
        self.assertTrue(any("authority.reward" in error for error in validate_ledger(item)))

    def test_native_claim_fails_closed(self):
        item = ledger(); item["native_claims"] = True
        self.assertTrue(any("native_claims" in error for error in validate_ledger(item)))


if __name__ == "__main__":
    unittest.main()
