import copy
import unittest

from tools.world.planetary_reward_duplicate_stale_guard_event_id_validator import validate_catalog


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
    guard_specs = (
        ("initial", 1, True, False, False, "reward_granted_g1"),
        ("duplicate_initial", 1, False, True, False, "reward_granted_duplicate_g1"),
        ("retry", 2, True, False, False, "reward_granted_g2"),
        ("duplicate_retry", 2, False, True, False, "reward_granted_duplicate_g2"),
        ("stale", 0, False, False, True, "reward_granted_stale_g0"),
    )
    activities = []
    for activity_id, authority in zip(activity_ids, authorities):
        reward_id = f"reward_{activity_id}"
        activities.append(
            {
                "activity_id": activity_id,
                "objective_id": f"objective_{activity_id}",
                "activity_authority_id": authority,
                "reward_authority_id": "game_flow_reward_authority",
                "reward_id": reward_id,
                "guards": [
                    {
                        "kind": kind,
                        "event_id": f"{activity_id}_{suffix}",
                        "generation": generation,
                        "accepted": accepted,
                        "duplicate_rejected": duplicate_rejected,
                        "stale_rejected": stale_rejected,
                        "reward_id": reward_id,
                        "reward_store_id": "game_flow_reward_store",
                        "committed_once": True,
                    }
                    for kind, generation, accepted, duplicate_rejected, stale_rejected, suffix in guard_specs
                ],
            }
        )
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_duplicate_stale_guard_event_ids",
        "evidence_mode": "detached_reward_guard_event_catalog",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "world_id": "ember_moon",
        "reward_store_id": "game_flow_reward_store",
        "guard_count": 25,
        "source_revision": "reward-guard-ids-v1",
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


class PlanetaryRewardDuplicateStaleGuardEventIdValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_catalog(evidence()), [])

    def test_event_ids_are_deterministic(self):
        item = evidence()
        item["activities"][0]["guards"][2]["event_id"] = "wrong_id"
        self.assertTrue(any("deterministic for its guard" in error for error in validate_catalog(item)))

    def test_guard_ids_are_globally_unique(self):
        item = evidence()
        item["activities"][4]["guards"][4]["event_id"] = item["activities"][0]["guards"][4]["event_id"]
        self.assertTrue(any("guard_ids must not contain duplicates" in error for error in validate_catalog(item)))

    def test_guard_order_is_required(self):
        item = evidence()
        item["activities"][1]["guards"][0], item["activities"][1]["guards"][1] = item["activities"][1]["guards"][1], item["activities"][1]["guards"][0]
        self.assertTrue(any("authored guard order" in error for error in validate_catalog(item)))

    def test_generation_is_required(self):
        item = evidence()
        item["activities"][2]["guards"][3]["generation"] = 3
        self.assertTrue(any("generation must be 2" in error for error in validate_catalog(item)))

    def test_reward_store_is_canonical(self):
        item = evidence()
        item["activities"][3]["guards"][1]["reward_store_id"] = "new_reward_store"
        self.assertTrue(any("canonical reward store" in error for error in validate_catalog(item)))

    def test_guard_count_matches_records(self):
        item = evidence()
        item["guard_count"] = 24
        self.assertTrue(any("guard_count must be exactly twenty-five" in error for error in validate_catalog(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_catalog(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
