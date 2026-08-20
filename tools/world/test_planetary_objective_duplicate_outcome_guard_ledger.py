import copy
import unittest

from tools.world.planetary_objective_duplicate_outcome_guard_ledger import validate_ledger


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
    outcome_types = (
        "objective_completed",
        "reward_queued",
        "reward_granted",
        "return_presented",
        "returned",
    )
    activities = []
    for activity_id, activity_authority in zip(activity_ids, authorities):
        outcomes = []
        for outcome_type in outcome_types:
            outcomes.append(
                {
                    "type": outcome_type,
                    "first_event_id": f"{activity_id}_{outcome_type}_first",
                    "duplicate_event_id": f"{activity_id}_{outcome_type}_duplicate",
                    "stale_event_id": f"{activity_id}_{outcome_type}_stale",
                    "first_generation": 1,
                    "first_accepted": True,
                    "duplicate_generation": 1,
                    "duplicate_accepted": False,
                    "duplicate_rejected": True,
                    "stale_generation": 0,
                    "stale_accepted": False,
                    "stale_rejected": True,
                    "committed_once": True,
                }
            )
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": activity_authority,
                "reward_id": f"reward_{activity_id}",
                "reward_authority_id": "game_flow_reward_authority",
                "reward_store_id": "game_flow_reward_store",
                "return_authority_id": "planetary_landing_return_contract",
                "return_target_id": "mudds_shipyards",
                "return_incentive_id": f"return_{activity_id}",
                "outcomes": outcomes,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_duplicate_outcome_guards",
        "evidence_mode": "detached_duplicate_outcome_ledger",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "return_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "reward_store_id": "game_flow_reward_store",
        "reward_store_ids": ["game_flow_reward_store"],
        "source_revision": "duplicate-outcome-v1",
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


class PlanetaryObjectiveDuplicateOutcomeGuardLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_ledger(evidence()), [])

    def test_outcome_order_is_required(self):
        item = evidence()
        item["activities"][0]["outcomes"][0], item["activities"][0]["outcomes"][1] = item["activities"][0]["outcomes"][1], item["activities"][0]["outcomes"][0]
        self.assertTrue(any("authored objective/reward/return order" in error for error in validate_ledger(item)))

    def test_duplicate_outcome_must_be_rejected(self):
        item = evidence()
        item["activities"][1]["outcomes"][2]["duplicate_accepted"] = True
        self.assertTrue(any("reject the duplicate" in error for error in validate_ledger(item)))

    def test_stale_outcome_must_be_rejected(self):
        item = evidence()
        item["activities"][2]["outcomes"][3]["stale_rejected"] = False
        self.assertTrue(any("reject the stale" in error for error in validate_ledger(item)))

    def test_first_outcome_must_be_accepted_once(self):
        item = evidence()
        item["activities"][3]["outcomes"][0]["first_accepted"] = False
        self.assertTrue(any("accept exactly one first-generation" in error for error in validate_ledger(item)))

    def test_duplicate_event_ids_are_rejected(self):
        item = evidence()
        item["activities"][4]["outcomes"][4]["stale_event_id"] = item["activities"][0]["outcomes"][4]["stale_event_id"]
        self.assertTrue(any("outcome_event_ids must not contain duplicates" in error for error in validate_ledger(item)))

    def test_reward_store_must_be_canonical(self):
        item = evidence()
        item["activities"][0]["reward_store_id"] = "new_reward_store"
        self.assertTrue(any("canonical reward store" in error for error in validate_ledger(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_ledger(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
