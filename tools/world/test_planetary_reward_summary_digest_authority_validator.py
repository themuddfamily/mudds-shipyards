import copy
import unittest

from tools.world.planetary_reward_summary_digest_authority_validator import validate_authority


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
    activities = [
        {
            "activity_id": activity_id,
            "activity_authority_id": activity_authority,
            "reward_id": f"reward_{activity_id}",
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "digest_included_once": True,
        }
        for activity_id, activity_authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 1,
        "evidence_scope": "planetary_reward_summary_digest_authority",
        "evidence_mode": "detached_reward_digest_authority",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "digest-authority-v1",
        "digest_sha256": "a" * 64,
        "digest_authority": {
            "owner_id": "game_flow_reward_authority",
            "store_id": "game_flow_reward_store",
            "source": "detached_evidence",
            "owns_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
        },
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


class PlanetaryRewardSummaryDigestAuthorityValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_authority(evidence()), [])

    def test_owner_must_be_existing_reward_authority(self):
        item = evidence()
        item["digest_authority"]["owner_id"] = "new_authority"
        self.assertTrue(any("owner_id" in error for error in validate_authority(item)))

    def test_store_must_be_canonical(self):
        item = evidence()
        item["digest_authority"]["store_id"] = "new_store"
        self.assertTrue(any("store_id" in error for error in validate_authority(item)))

    def test_digest_authority_cannot_write_runtime(self):
        item = evidence()
        item["digest_authority"]["writes_runtime"] = True
        self.assertTrue(any("writes_runtime" in error for error in validate_authority(item)))

    def test_digest_authority_cannot_run_native(self):
        item = evidence()
        item["digest_authority"]["runs_native"] = True
        self.assertTrue(any("runs_native" in error for error in validate_authority(item)))

    def test_activity_order_is_required(self):
        item = evidence()
        item["activities"].reverse()
        self.assertTrue(any("authored activity order" in error for error in validate_authority(item)))

    def test_digest_format_is_lowercase_sha256(self):
        item = evidence()
        item["digest_sha256"] = "Z" * 64
        self.assertTrue(any("lowercase SHA-256" in error for error in validate_authority(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_authority(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
