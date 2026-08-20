import copy
import unittest

from tools.world.planetary_objective_event_sequence_contiguous_validator import validate_stream


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
    activities = [
        {
            "activity_id": activity_id,
            "objective_id": f"objective_{activity_id}",
            "activity_authority_id": authority,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    events = []
    for activity_index, (activity_id, authority) in enumerate(zip(activity_ids, authorities)):
        for local_index, event_type in enumerate(event_types):
            events.append(
                {
                    "activity_id": activity_id,
                    "activity_authority_id": authority,
                    "type": event_type,
                    "event_id": f"{activity_id}_{event_type}",
                    "global_sequence": activity_index * 6 + local_index,
                    "activity_sequence": local_index,
                    "occurrence": 1,
                }
            )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_objective_event_sequence_contiguous",
        "evidence_mode": "detached_contiguous_event_stream",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "event_count": 30,
        "source_revision": "contiguous-stream-v1",
        "activities": activities,
        "events": events,
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


class PlanetaryObjectiveEventSequenceContiguousValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_stream(evidence()), [])

    def test_global_sequence_must_be_contiguous(self):
        item = evidence()
        item["events"][12]["global_sequence"] = 29
        self.assertTrue(any("global_sequence must be contiguous" in error for error in validate_stream(item)))

    def test_local_sequence_must_be_contiguous(self):
        item = evidence()
        item["events"][8]["activity_sequence"] = 5
        self.assertTrue(any("activity_sequence must be contiguous" in error for error in validate_stream(item)))

    def test_activity_order_is_required(self):
        item = evidence()
        item["events"][6], item["events"][12] = item["events"][12], item["events"][6]
        self.assertTrue(any("activity_id must be ember_caldera_patrol" in error for error in validate_stream(item)))

    def test_event_ids_must_be_unique(self):
        item = evidence()
        item["events"][29]["event_id"] = item["events"][0]["event_id"]
        self.assertTrue(any("event_ids must not contain duplicates" in error for error in validate_stream(item)))

    def test_event_authority_must_match_activity(self):
        item = evidence()
        item["events"][18]["activity_authority_id"] = "activity_director"
        self.assertTrue(any("authority_id must match" in error for error in validate_stream(item)))

    def test_event_occurrence_is_exactly_once(self):
        item = evidence()
        item["events"][24]["occurrence"] = 2
        self.assertTrue(any("occurrence must be exactly one" in error for error in validate_stream(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_stream(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
