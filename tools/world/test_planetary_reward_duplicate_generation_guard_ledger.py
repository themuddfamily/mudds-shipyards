import copy
import unittest

from tools.world.planetary_reward_duplicate_generation_guard_ledger import validate_ledger


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
    submission_specs = (
        ("initial", 1, True, False, False),
        ("duplicate_initial", 1, False, True, False),
        ("retry", 2, True, False, False),
        ("duplicate_retry", 2, False, True, False),
        ("stale", 0, False, False, True),
    )
    activities = []
    for activity_id, activity_authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        reward_event_id = f"{activity_id}_reward_granted"
        submissions = [
            {
                "kind": kind,
                "generation": generation,
                "accepted": accepted,
                "duplicate_rejected": duplicate_rejected,
                "stale_rejected": stale_rejected,
                "reward_event_id": reward_event_id,
                "reward_id": reward_id,
                "reward_store_id": "game_flow_reward_store",
                "guard_event_id": f"{activity_id}_{kind}",
                "committed_once": True,
            }
            for kind, generation, accepted, duplicate_rejected, stale_rejected in submission_specs
        ]
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": activity_authority,
                "reward_authority_id": "game_flow_reward_authority",
                "reward_id": reward_id,
                "reward_event_id": reward_event_id,
                "submissions": submissions,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_duplicate_generation_guards",
        "evidence_mode": "detached_reward_generation_fixture",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "reward_store_ids": ["game_flow_reward_store"],
        "source_revision": "reward-generation-v1",
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


class PlanetaryRewardDuplicateGenerationGuardLedgerTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_ledger(evidence()), [])

    def test_retry_generation_is_accepted(self):
        item = evidence()
        item["activities"][0]["submissions"][2]["accepted"] = False
        self.assertTrue(any("invalid generation outcome" in error for error in validate_ledger(item)))

    def test_duplicate_retry_is_rejected(self):
        item = evidence()
        item["activities"][1]["submissions"][3]["duplicate_rejected"] = False
        self.assertTrue(any("duplicate generation-one" in error or "invalid generation outcome" in error for error in validate_ledger(item)))

    def test_stale_generation_is_rejected(self):
        item = evidence()
        item["activities"][2]["submissions"][4]["stale_rejected"] = False
        self.assertTrue(any("stale generation-zero" in error or "invalid generation outcome" in error for error in validate_ledger(item)))

    def test_reward_event_reference_is_required(self):
        item = evidence()
        item["activities"][3]["submissions"][0]["reward_event_id"] = "other_event"
        self.assertTrue(any("reference the activity reward event" in error for error in validate_ledger(item)))

    def test_guard_event_ids_are_unique(self):
        item = evidence()
        item["activities"][4]["submissions"][4]["guard_event_id"] = item["activities"][0]["submissions"][4]["guard_event_id"]
        self.assertTrue(any("guard_event_ids must not contain duplicates" in error for error in validate_ledger(item)))

    def test_reward_store_is_canonical(self):
        item = evidence()
        item["activities"][0]["submissions"][1]["reward_store_id"] = "new_reward_store"
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
