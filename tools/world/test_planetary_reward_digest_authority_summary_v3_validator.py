import copy
import unittest

from tools.world.planetary_reward_digest_authority_summary_v3_validator import validate_summary


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
            "evidence_ref": f"res://evidence/reward_digest/{activity_id}.json",
            "status": "PASS",
            "included_once": True,
        }
        for activity_id, authority in zip(activity_ids, authorities)
    ]
    return {
        "schema_version": 3,
        "evidence_scope": "planetary_reward_digest_authority_summary_v3",
        "evidence_mode": "detached_reward_digest_authority_v3",
        "runtime_authority": False,
        "reward_inventory": False,
        "reward_runtime": False,
        "native_claims": False,
        "historical_claim": False,
        "procedural_generation": False,
        "world_id": "ember_moon",
        "source_revision": "digest-authority-v3",
        "digest_sha256": "c" * 64,
        "digest_authority": {
            "owner_id": "game_flow_reward_authority",
            "store_id": "game_flow_reward_store",
            "return_authority_id": "planetary_landing_return_contract",
            "source": "detached_evidence",
            "contract_revision": "reward_digest_authority_v3",
            "owns_inventory": False,
            "writes_runtime": False,
            "runs_native": False,
        },
        "handoffs": [
            {"id": "objective_evidence_to_reward", "source": "objective_evidence", "target": "game_flow_reward_authority", "runtime_wired": False, "mutates_inventory": False, "native_run": False, "committed_once": True},
            {"id": "reward_to_store", "source": "game_flow_reward_authority", "target": "game_flow_reward_store", "runtime_wired": False, "mutates_inventory": False, "native_run": False, "committed_once": True},
            {"id": "reward_to_return", "source": "game_flow_reward_authority", "target": "planetary_landing_return_contract", "runtime_wired": False, "mutates_inventory": False, "native_run": False, "committed_once": True},
        ],
        "records": records,
        "counts": {"records": 5, "handoffs": 3, "digest_leaves": 5, "pass_records": 5, "runtime_mutations": 0, "inventory_writes": 0, "native_runs": 0},
        "overall_status": "PASS",
    }


class PlanetaryRewardDigestAuthoritySummaryV3ValidatorTest(unittest.TestCase):
    def test_fixture_is_valid(self):
        self.assertEqual(validate_summary(evidence()), [])

    def test_schema_version_is_v3(self):
        item = evidence()
        item["schema_version"] = 2
        self.assertTrue(any("schema_version must be 3" in error for error in validate_summary(item)))

    def test_handoff_order_and_targets_are_required(self):
        item = evidence()
        item["handoffs"][1]["target"] = "other_store"
        self.assertTrue(any("source/target must match" in error for error in validate_summary(item)))

    def test_handoff_must_be_non_runtime(self):
        item = evidence()
        item["handoffs"][2]["runtime_wired"] = True
        self.assertTrue(any("detached and non-mutating" in error for error in validate_summary(item)))

    def test_handoff_ids_are_unique(self):
        item = evidence()
        item["handoffs"][2]["id"] = item["handoffs"][0]["id"]
        self.assertTrue(any("handoff_ids must not contain duplicates" in error for error in validate_summary(item)))

    def test_evidence_refs_are_unique_res_paths(self):
        item = evidence()
        item["records"][4]["evidence_ref"] = item["records"][0]["evidence_ref"]
        self.assertTrue(any("evidence_refs must not contain duplicates" in error for error in validate_summary(item)))

    def test_counts_must_match_handoffs(self):
        item = evidence()
        item["counts"]["handoffs"] = 2
        self.assertTrue(any("counts.handoffs must be 3" in error for error in validate_summary(item)))

    def test_runtime_and_native_claims_fail_closed(self):
        item = copy.deepcopy(evidence())
        item["runtime_authority"] = True
        item["native_claims"] = True
        errors = validate_summary(item)
        self.assertTrue(any("runtime_authority" in error for error in errors))
        self.assertTrue(any("native_claims" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
