import copy
import unittest

from tools.world.planetary_reward_authority_store_digest_summary_v5_validator import validate_summary


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
            "digest_leaf_id": f"{activity_id}_authority_store_leaf",
            "evidence_ref": f"res://evidence/authority_store/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 5,
        "evidence_scope": "planetary_reward_authority_store_digest_summary_v5",
        "evidence_mode": "detached_reward_authority_store_digest_v5",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "authority-store-v5",
        "digest_sha256": "e" * 64,
        "authority_store_join": {
            "reward_authority_id": "game_flow_reward_authority",
            "reward_store_id": "game_flow_reward_store",
            "source": "detached_evidence",
            "store_created_here": False,
            "inventory_writer_here": False,
            "runtime_wired": False,
            "native_run": False,
            "committed_once": True,
        },
        "records": records,
        "counts": {"records": 5, "digest_leaves": 5, "pass_records": 5, "store_creations": 0, "inventory_writes": 0, "runtime_mutations": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardAuthorityStoreDigestSummaryV5ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_summary(evidence()), [])

    def test_schema_version_is_v5(self):
        item = evidence()
        item["schema_version"] = 4
        self.assertTrue(any("schema_version must be 5" in error for error in validate_summary(item)))

    def test_authority_store_join_is_canonical(self):
        item = evidence()
        item["authority_store_join"]["reward_store_id"] = "new_store"
        self.assertTrue(any("authority_store_join.reward_store_id" in error for error in validate_summary(item)))

    def test_store_creation_is_forbidden(self):
        item = evidence()
        item["authority_store_join"]["store_created_here"] = True
        self.assertTrue(any("store_created_here must be false" in error for error in validate_summary(item)))

    def test_records_use_canonical_store(self):
        item = evidence()
        item["records"][0]["reward_store_id"] = "new_store"
        self.assertTrue(any("existing reward authority and store" in error for error in validate_summary(item)))

    def test_evidence_refs_are_unique(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_summary(item)))

    def test_counts_must_show_no_store_creation(self):
        item = evidence()
        item["counts"]["store_creations"] = 1
        self.assertTrue(any("counts.store_creations must be 0" in error for error in validate_summary(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_summary(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
