import copy
import unittest

from tools.world.planetary_reward_digest_authority_summary_v2_validator import validate_summary


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
    records = [
        {
            "activity_id": activity_id,
            "activity_authority_id": authority,
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "reward_id": f"reward_{activity_id}",
            "digest_leaf_id": f"{activity_id}_reward_digest_leaf",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 2,
        "evidence_scope": "planetary_reward_digest_authority_summary_v2",
        "evidence_mode": "detached_reward_digest_authority_v2",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "digest-authority-v2",
        "digest_sha256": "b" * 64,
        "digest_authority": {
            "owner_id": "game_flow_reward_authority",
            "store_id": "game_flow_reward_store",
            "source": "detached_evidence",
            "contract_revision": "reward_digest_authority_v2",
            "owns_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
        },
        "authority_matrix": {
            "objective": False,
            "activity": False,
            "reward": False,
            "reward_store": False,
            "save": False,
            "network": False,
            "gameplay": False,
            "movement": False,
            "native": False,
        },
        "records": records,
        "counts": {
            "records": 5,
            "digest_leaves": 5,
            "pass_records": 5,
            "runtime_mutations": 0,
            "inventory_writes": 0,
            "native_runs": 0,
        },
        "overall_status": "PASS",
    }


class PlanetaryRewardDigestAuthoritySummaryV2ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_summary(evidence()), [])

    def test_schema_version_is_v2(self):
        item = evidence()
        item["schema_version"] = 1
        self.assertTrue(any("schema_version must be 2" in error for error in validate_summary(item)))

    def test_contract_revision_is_required(self):
        item = evidence()
        item["digest_authority"]["contract_revision"] = "old_revision"
        self.assertTrue(any("contract_revision" in error for error in validate_summary(item)))

    def test_authority_matrix_must_be_detached(self):
        item = evidence()
        item["authority_matrix"]["reward"] = True
        self.assertTrue(any("authority_matrix.reward" in error for error in validate_summary(item)))

    def test_counts_must_match_records(self):
        item = evidence()
        item["counts"]["digest_leaves"] = 4
        self.assertTrue(any("counts.digest_leaves must be 5" in error for error in validate_summary(item)))

    def test_digest_leaf_ids_are_unique(self):
        item = evidence()
        item["records"][4]["digest_leaf_id"] = item["records"][0]["digest_leaf_id"]
        self.assertTrue(any("digest_leaf_ids must not contain duplicates" in error for error in validate_summary(item)))

    def test_overall_status_must_pass(self):
        item = evidence()
        item["overall_status"] = "NOT_RUN"
        self.assertTrue(any("overall_status must be PASS" in error for error in validate_summary(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_summary(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
