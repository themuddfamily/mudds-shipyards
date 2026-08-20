import copy
import unittest

from tools.world.planetary_reward_queue_grant_return_duplicate_guard_validator import validate_guards


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
    activities = []
    for activity_id, activity_authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        incentive_id = f"return_{activity_id}"
        guards = {}
        for guard_name in ("queue", "grant", "return"):
            guard = {
                "event_id": f"{activity_id}_{guard_name}",
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
            if guard_name in {"queue", "grant"}:
                guard["reward_id"] = reward_id
                guard["reward_store_id"] = "game_flow_reward_store"
            else:
                guard["return_incentive_id"] = incentive_id
                guard["return_target_id"] = "mudds_shipyards"
            guards[guard_name] = guard
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": activity_authority,
                "reward_authority_id": "game_flow_reward_authority",
                "return_authority_id": "planetary_landing_return_contract",
                "return_target_id": "mudds_shipyards",
                "reward_id": reward_id,
                "return_incentive_id": incentive_id,
                "guards": guards,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_queue_grant_return_duplicate_guards",
        "evidence_mode": "detached_reward_guard_fixture",
        "runtime_authority": False,
        "objective_runtime": False,
        "reward_inventory": False,
        "return_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "return_target_id": "mudds_shipyards",
        "reward_store_id": "game_flow_reward_store",
        "reward_store_ids": ["game_flow_reward_store"],
        "source_revision": "reward-guards-v1",
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


class PlanetaryRewardQueueGrantReturnDuplicateGuardValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_guards(evidence()), [])

    def test_queue_duplicate_is_rejected(self):
        item = evidence()
        item["activities"][0]["guards"]["queue"]["duplicate_rejected"] = False
        self.assertTrue(any("reject duplicate" in error for error in validate_guards(item)))

    def test_grant_stale_is_rejected(self):
        item = evidence()
        item["activities"][1]["guards"]["grant"]["stale_rejected"] = False
        self.assertTrue(any("reject stale" in error for error in validate_guards(item)))

    def test_return_guard_matches_incentive(self):
        item = evidence()
        item["activities"][2]["guards"]["return"]["return_incentive_id"] = "other_incentive"
        self.assertTrue(any("match the activity incentive" in error for error in validate_guards(item)))

    def test_reward_guards_share_reward_store(self):
        item = evidence()
        item["activities"][3]["guards"]["grant"]["reward_store_id"] = "new_reward_store"
        self.assertTrue(any("canonical reward store" in error for error in validate_guards(item)))

    def test_guard_event_ids_are_unique(self):
        item = evidence()
        item["activities"][4]["guards"]["return"]["event_id"] = item["activities"][0]["guards"]["return"]["event_id"]
        self.assertTrue(any("guard_event_ids must not contain duplicates" in error for error in validate_guards(item)))

    def test_reward_ids_are_unique(self):
        item = evidence()
        item["activities"][4]["reward_id"] = item["activities"][0]["reward_id"]
        self.assertTrue(any("reward_ids must not contain duplicates" in error for error in validate_guards(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_guards(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
