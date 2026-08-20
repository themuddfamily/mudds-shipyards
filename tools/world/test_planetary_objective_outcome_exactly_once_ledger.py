import copy
import unittest

from tools.world.planetary_objective_outcome_exactly_once_ledger import validate_ledger


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
        events = [
            {
                "type": event_type,
                "event_id": f"{activity_id}_{event_type}",
                "sequence": sequence,
                "occurrence": 1,
                "generation": 1,
                "committed_once": True,
            }
            for sequence, event_type in enumerate(event_types)
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
                "reward_event_id": events[3]["event_id"],
                "return_event_id": events[5]["event_id"],
                "objective_completed_once": True,
                "reward_queued_once": True,
                "reward_granted_once": True,
                "return_presented_once": True,
                "returned_once": True,
                "duplicate_outcome_rejected": True,
                "events": events,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_outcome_exactly_once",
        "evidence_mode": "detached_outcome_order_ledger",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "return_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "reward_store_id": "game_flow_reward_store",
        "reward_store_ids": ["game_flow_reward_store"],
        "source_revision": "objective-outcome-v1",
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


class PlanetaryObjectiveOutcomeExactlyOnceLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_ledger(evidence()), [])

    def test_outcome_order_is_required(self):
        item = evidence()
        item["activities"][0]["events"][2], item["activities"][0]["events"][3] = item["activities"][0]["events"][3], item["activities"][0]["events"][2]
        self.assertTrue(any("authored objective outcome order" in error for error in validate_ledger(item)))

    def test_occurrence_must_be_exactly_once(self):
        item = evidence()
        item["activities"][1]["events"][3]["occurrence"] = 2
        self.assertTrue(any("occurrence must be exactly one" in error for error in validate_ledger(item)))

    def test_reward_event_reference_is_required(self):
        item = evidence()
        item["activities"][2]["reward_event_id"] = "other_reward_event"
        self.assertTrue(any("reward_event_id" in error for error in validate_ledger(item)))

    def test_duplicate_outcome_guard_is_required(self):
        item = evidence()
        item["activities"][3]["duplicate_outcome_rejected"] = False
        self.assertTrue(any("duplicate_outcome_rejected" in error for error in validate_ledger(item)))

    def test_reward_store_must_be_canonical(self):
        item = evidence()
        item["reward_store_ids"] = ["game_flow_reward_store", "another_store"]
        self.assertTrue(any("one canonical store only" in error for error in validate_ledger(item)))

    def test_return_target_must_be_mudds(self):
        item = evidence()
        item["activities"][4]["return_target_id"] = "other_destination"
        self.assertTrue(any("return_target_id must be mudds_shipyards" in error for error in validate_ledger(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_ledger(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
