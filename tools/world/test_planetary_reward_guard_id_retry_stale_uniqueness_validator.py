import copy
import unittest

from tools.world.planetary_reward_guard_id_retry_stale_uniqueness_validator import validate_catalog


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
    rewards = []
    for activity_id, authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        rewards.append(
            {
                "activity_id": activity_id,
                "activity_authority_id": authority,
                "reward_authority_id": "game_flow_reward_authority",
                "reward_id": reward_id,
                "retry_guard_id": f"{activity_id}_reward_retry_g2",
                "stale_guard_id": f"{activity_id}_reward_stale_g0",
                "retry_generation": 2,
                "retry_accepted": True,
                "stale_generation": 0,
                "stale_accepted": False,
                "stale_rejection_reason": "stale_generation",
                "retry_reward_id": reward_id,
                "stale_reward_id": reward_id,
                "retry_reward_store_id": "game_flow_reward_store",
                "stale_reward_store_id": "game_flow_reward_store",
                "retry_committed_once": True,
                "stale_committed_once": True,
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_guard_id_retry_stale_uniqueness",
        "evidence_mode": "detached_reward_keyed_guard_catalog",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "guard_id_count": 10,
        "source_revision": "keyed-guard-uniqueness-v1",
        "rewards": rewards,
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


class PlanetaryRewardGuardIdRetryStaleUniquenessValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_catalog(evidence()), [])

    def test_retry_id_is_deterministic(self):
        item = evidence()
        item["rewards"][0]["retry_guard_id"] = "wrong_retry_id"
        self.assertTrue(any("retry_guard_id must be deterministic" in error for error in validate_catalog(item)))

    def test_stale_id_is_deterministic(self):
        item = evidence()
        item["rewards"][1]["stale_guard_id"] = "wrong_stale_id"
        self.assertTrue(any("stale_guard_id must be deterministic" in error for error in validate_catalog(item)))

    def test_guard_ids_are_unique(self):
        item = evidence()
        item["rewards"][4]["stale_guard_id"] = item["rewards"][0]["stale_guard_id"]
        self.assertTrue(any("guard_ids must not contain duplicates" in error for error in validate_catalog(item)))

    def test_retry_generation_is_two(self):
        item = evidence()
        item["rewards"][2]["retry_generation"] = 1
        self.assertTrue(any("accept retry generation two" in error for error in validate_catalog(item)))

    def test_stale_reason_is_required(self):
        item = evidence()
        item["rewards"][3]["stale_rejection_reason"] = "other_reason"
        self.assertTrue(any("stale_rejection_reason" in error for error in validate_catalog(item)))

    def test_reward_store_is_canonical(self):
        item = evidence()
        item["rewards"][0]["retry_reward_store_id"] = "new_reward_store"
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
