import copy
import unittest

from tools.world.planetary_objective_event_id_order_validator import validate_catalog


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
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": activity_authority,
                "reward_store_id": "game_flow_reward_store",
                "events": [
                    {
                        "type": event_type,
                        "event_id": f"{activity_id}_{event_type}",
                        "sequence": sequence,
                        "occurrence": 1,
                    }
                    for sequence, event_type in enumerate(event_types)
                ],
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_event_id_order",
        "evidence_mode": "detached_event_catalog",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "event_count": 30,
        "source_revision": "event-catalog-v1",
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


class PlanetaryObjectiveEventIdOrderValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_catalog(evidence()), [])

    def test_event_ids_are_deterministic(self):
        item = evidence()
        item["activities"][0]["events"][2]["event_id"] = "wrong_event_id"
        self.assertTrue(any("event_id must be ember_beacon_survey_reward_queued" in error for error in validate_catalog(item)))

    def test_duplicate_event_ids_are_rejected(self):
        item = evidence()
        item["activities"][1]["events"][5]["event_id"] = item["activities"][0]["events"][5]["event_id"]
        self.assertTrue(any("event_ids must not contain duplicates" in error for error in validate_catalog(item)))

    def test_event_order_is_required(self):
        item = evidence()
        item["activities"][2]["events"][0], item["activities"][2]["events"][1] = item["activities"][2]["events"][1], item["activities"][2]["events"][0]
        self.assertTrue(any("authored objective event order" in error for error in validate_catalog(item)))

    def test_sequence_is_contiguous(self):
        item = evidence()
        item["activities"][3]["events"][4]["sequence"] = 2
        self.assertTrue(any("sequence must be contiguous" in error for error in validate_catalog(item)))

    def test_event_occurrence_is_exactly_once(self):
        item = evidence()
        item["activities"][4]["events"][3]["occurrence"] = 2
        self.assertTrue(any("occurrence must be exactly one" in error for error in validate_catalog(item)))

    def test_reward_store_is_canonical(self):
        item = evidence()
        item["activities"][0]["reward_store_id"] = "new_reward_store"
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
