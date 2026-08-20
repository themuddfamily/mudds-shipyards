import copy
import unittest

from tools.world.planetary_keyed_reward_retry_stale_event_mapping_ledger import validate_ledger


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
    events = []
    for activity_id, authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        events.extend(
            [
                {
                    "activity_id": activity_id,
                    "event_type": "reward_retry",
                    "event_id": f"{activity_id}_reward_retry_g2",
                    "submitted_generation": 2,
                    "source_generation": 1,
                    "current_generation": 2,
                    "accepted": True,
                    "rejected": False,
                    "reason": "retry_generation",
                    "reward_id": reward_id,
                    "activity_authority_id": authority,
                    "reward_authority_id": "game_flow_reward_authority",
                    "reward_store_id": "game_flow_reward_store",
                    "committed_once": True,
                },
                {
                    "activity_id": activity_id,
                    "event_type": "reward_stale",
                    "event_id": f"{activity_id}_reward_stale_g0",
                    "submitted_generation": 0,
                    "source_generation": 0,
                    "current_generation": 2,
                    "accepted": False,
                    "rejected": True,
                    "reason": "stale_generation",
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
        "evidence_scope": "planetary_keyed_reward_retry_stale_event_mapping",
        "evidence_mode": "detached_keyed_reward_event_ledger",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "event_count": 10,
        "source_revision": "keyed-event-ledger-v1",
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


class PlanetaryKeyedRewardRetryStaleEventMappingLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_ledger(evidence()), [])

    def test_retry_event_is_deterministic(self):
        item = evidence()
        item["events"][0]["event_id"] = "wrong_id"
        self.assertTrue(any("deterministic for the mapping" in error for error in validate_ledger(item)))

    def test_stale_event_is_rejected(self):
        item = evidence()
        item["events"][3]["rejected"] = False
        self.assertTrue(any("invalid event outcome" in error for error in validate_ledger(item)))

    def test_generation_fence_is_required(self):
        item = evidence()
        item["events"][2]["current_generation"] = 1
        self.assertTrue(any("source/current generations" in error for error in validate_ledger(item)))

    def test_stale_reason_is_required(self):
        item = evidence()
        item["events"][5]["reason"] = "other_reason"
        self.assertTrue(any("reason must be stale_generation" in error for error in validate_ledger(item)))

    def test_event_ids_are_unique(self):
        item = evidence()
        item["events"][9]["event_id"] = item["events"][1]["event_id"]
        self.assertTrue(any("event_ids must not contain duplicates" in error for error in validate_ledger(item)))

    def test_reward_pair_must_match(self):
        item = evidence()
        item["events"][7]["reward_id"] = "other_reward"
        self.assertTrue(any("share one reward ID" in error for error in validate_ledger(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_ledger(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
