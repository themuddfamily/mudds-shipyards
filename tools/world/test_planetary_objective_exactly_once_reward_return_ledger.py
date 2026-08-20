import copy
import unittest

from tools.world.planetary_objective_exactly_once_reward_return_ledger import validate_ledger


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
        "objective_accepted",
        "objective_completed",
        "reward_granted",
        "return_presented",
        "returned",
    )
    activities = []
    for activity_id, activity_authority in zip(activity_ids, authorities):
        events = [
            {"type": event_type, "event_id": f"{activity_id}_{event_type}", "occurrence": 1}
            for event_type in event_types
        ]
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
                "reward_event_id": events[2]["event_id"],
                "return_event_id": events[4]["event_id"],
                "objective_completed_once": True,
                "reward_granted_once": True,
                "return_presented_once": True,
                "returned_once": True,
                "duplicate_objective_rejected": True,
                "duplicate_reward_rejected": True,
                "duplicate_return_rejected": True,
                "events": events,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_exactly_once_reward_return",
        "evidence_mode": "detached_event_ledger",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "return_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "reward_store_id": "game_flow_reward_store",
        "reward_store_ids": ["game_flow_reward_store"],
        "source_revision": "objective-event-ledger-v1",
        "activities": activities,
        "authority": {
            "objective": False,
            "activity": False,
            "reward": False,
            "reward_store": False,
            "return": False,
            "save": False,
            "network": False,
            "gameplay": False,
        },
    }


class PlanetaryObjectiveExactlyOnceRewardReturnLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_ledger(evidence()), [])

    def test_event_order_is_required(self):
        item = evidence()
        item["activities"][0]["events"][2], item["activities"][0]["events"][3] = item["activities"][0]["events"][3], item["activities"][0]["events"][2]
        self.assertTrue(any("authored objective/reward/return order" in error for error in validate_ledger(item)))

    def test_event_occurrence_must_be_exactly_once(self):
        item = evidence()
        item["activities"][1]["events"][2]["occurrence"] = 2
        self.assertTrue(any("occurrence must be exactly one" in error for error in validate_ledger(item)))

    def test_reward_event_must_be_referenced(self):
        item = evidence()
        item["activities"][2]["reward_event_id"] = "other_reward_event"
        self.assertTrue(any("reward_event_id" in error for error in validate_ledger(item)))

    def test_only_canonical_reward_store_is_allowed(self):
        item = evidence()
        item["activities"][3]["reward_store_id"] = "planetary_reward_store"
        self.assertTrue(any("canonical reward store" in error for error in validate_ledger(item)))

    def test_duplicate_event_ids_are_rejected(self):
        item = evidence()
        item["activities"][4]["events"][4]["event_id"] = item["activities"][0]["events"][4]["event_id"]
        self.assertTrue(any("event_ids must not contain duplicates" in error for error in validate_ledger(item)))

    def test_return_authority_is_existing_and_external(self):
        item = evidence()
        item["activities"][0]["return_authority_id"] = "new_return_authority"
        self.assertTrue(any("return_authority_id" in error for error in validate_ledger(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_ledger(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
